"""6단계: 정리(허공에 뜬 가우시안 지우기) → 한 바퀴 돌려 가며 렌더링(배경 투명 WebP) → 3D 파일(.ply) · 확인용 PSNR

- 실루엣 검사: 학습 사진에서 SAM 3 마스크 밖에 놓이는 비율이 높은 가우시안은 버린다 (가장자리 지느러미 같은 잡티)
- 회전 기준: 학습 사진 0번(영상 첫 프레임, 정면 · 똑바로 선 모습)의 카메라. 그 카메라의 위쪽을 축으로 돈다
"""

import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np
import torch
import torch.nn.functional as F
from gsplat import rasterization
from PIL import Image
from plyfile import PlyData, PlyElement

from common import largest_cluster
from train import holdout_ids, load_views, render


def look_at(eye: np.ndarray, target: np.ndarray, up: np.ndarray) -> np.ndarray:
    """OpenCV 카메라(x 오른쪽, y 아래, z 앞) world → camera"""
    z = (target - eye) / np.linalg.norm(target - eye)
    x = np.cross(z, up)
    x /= np.linalg.norm(x)
    r = np.stack([x, np.cross(z, x), z])
    m = np.eye(4)
    m[:3, :3] = r
    m[:3, 3] = -r @ eye
    return m


def rotate(v: np.ndarray, axis: np.ndarray, ang: float) -> np.ndarray:
    axis = axis / np.linalg.norm(axis)
    return v * math.cos(ang) + np.cross(axis, v) * math.sin(ang) + axis * (axis @ v) * (1 - math.cos(ang))


def save_ply(path: Path, p: dict) -> None:
    """3D 가우시안 스플래팅 표준 .ply (SuperSplat 같은 뷰어에서 열린다)"""
    n = len(p["means"])
    attrs = ["x", "y", "z", "nx", "ny", "nz", *[f"f_dc_{i}" for i in range(3)], *[f"f_rest_{i}" for i in range(45)]]
    attrs += ["opacity", "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3"]
    arr = np.concatenate(
        [
            p["means"].numpy(),
            np.zeros((n, 3)),
            p["sh0"].reshape(n, 3).numpy(),
            p["shN"].transpose(1, 2).reshape(n, 45).numpy(),
            p["opacities"].reshape(n, 1).numpy(),
            p["scales"].numpy(),
            F.normalize(p["quats"], dim=-1).numpy(),
        ],
        1,
    ).astype(np.float32)
    el = np.empty(n, dtype=[(a, "f4") for a in attrs])
    for i, a in enumerate(attrs):
        el[a] = arr[:, i]
    PlyData([PlyElement.describe(el, "vertex")]).write(str(path))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--out", type=Path, required=True, help="회전 그림을 넣을 폴더 (앱: frontend/assets/room/<id>)")
    ap.add_argument("--count", type=int, default=72)
    ap.add_argument("--size", type=int, default=400)
    ap.add_argument("--zoom", type=float, default=0.7, help="1보다 작으면 멀리서")
    ap.add_argument("--hull", type=float, default=0.75, help="마스크 안에 들어오는 비율이 이보다 낮으면 버림")
    ap.add_argument("--ply", type=Path, default=None)
    args = ap.parse_args()
    dev = "cuda"
    args.out.mkdir(parents=True, exist_ok=True)

    ck = torch.load(args.work / "gaussians.pt", weights_only=False)
    p, center = ck["params"], np.asarray(ck["center"], np.float64)
    cams, rgb, mask, ignore = load_views(args.work / "views")
    n, h, w = mask.shape
    means = p["means"].numpy()
    hom = np.concatenate([means, np.ones((len(means), 1))], 1)
    inside = np.zeros(len(means))
    seen = np.zeros(len(means))
    hold = set(holdout_ids(n, ck["holdout"]))
    for i, c in enumerate(cams):
        if i in hold:  # 확인용 사진은 정리에도 쓰지 않는다 (PSNR을 공정하게)
            continue
        m = cv2.dilate((mask[i] > 0.5).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
        cam = (np.asarray(c["viewmat"]) @ hom.T)[:3]
        u, v = ((np.asarray(c["K"]) @ cam)[:2] / np.maximum(cam[2], 1e-6)).round().astype(int)
        ok = np.where((cam[2] > 0) & (u >= 0) & (u < w) & (v >= 0) & (v < h))[0]
        ok = ok[~ignore[i, v[ok], u[ok]]]
        seen[ok] += 1
        inside[ok] += m[v[ok], u[ok]]
    dist = np.linalg.norm(means - center, axis=1)
    keep = (seen >= 3) & (inside / np.maximum(seen, 1) >= args.hull)
    keep &= torch.sigmoid(p["opacities"]).numpy() > 0.02
    keep &= torch.exp(p["scales"]).amax(-1).numpy() < np.percentile(dist, 95) * 0.25  # 너무 큰 납작한 조각
    p = {k: v[torch.from_numpy(keep)] for k, v in p.items()}
    # 카메라 가까이에 생기는 작은 복사본(floater 덩어리)을 지우고 가장 큰 덩어리만
    main_body = torch.from_numpy(largest_cluster(p["means"].numpy(), torch.sigmoid(p["opacities"]).numpy()))
    p = {k: v[main_body] for k, v in p.items()}
    g = {k: v.to(dev) for k, v in p.items()}
    print("gaussians", len(p["means"]), "/", len(keep))

    # 정리한 뒤 확인용(학습에 안 쓴) 사진 PSNR
    vals = []
    with torch.no_grad():
        for i in sorted(hold):
            vm = torch.tensor(cams[i]["viewmat"], device=dev).float()
            K = torch.tensor(cams[i]["K"], device=dev).float()
            out, _, _ = render(g, vm, K, w, h)
            valid = torch.tensor(~ignore[i], device=dev)
            vals.append(float(-10 * torch.log10(((out[0] - torch.tensor(rgb[i], device=dev)) ** 2).mean(-1)[valid].mean())))
    psnr = round(float(np.mean(vals)), 2)
    print("holdout PSNR after cleanup", psnr, "views", len(vals))

    vm0 = np.asarray(cams[0]["viewmat"])
    r0 = vm0[:3, :3]
    up = -r0.T @ np.array([0.0, 1.0, 0.0])
    off = (-r0.T @ vm0[:3, 3] - center) / args.zoom
    f = cams[0]["K"][0][0] * args.size / w
    K = torch.tensor([[f, 0, args.size / 2], [0, f, args.size / 2], [0, 0, 1]], device=dev, dtype=torch.float32)
    colors = torch.cat([g["sh0"], g["shN"]], 1)
    for i in range(args.count):
        vm = torch.tensor(look_at(center + rotate(off, up, 2 * math.pi * i / args.count), center, up), device=dev, dtype=torch.float32)
        with torch.no_grad():
            out, alpha, _ = rasterization(
                g["means"],
                F.normalize(g["quats"], dim=-1),
                torch.exp(g["scales"]),
                torch.sigmoid(g["opacities"]),
                colors,
                vm[None],
                K[None],
                args.size,
                args.size,
                sh_degree=3,
                packed=False,
                rasterize_mode="antialiased",
            )
        a = alpha[0].clamp(0, 1)
        rgb_ = (out[0] / a.clamp_min(1e-4)).clamp(0, 1)  # 배경 없이 그린 색은 alpha가 곱해져 있다
        a = torch.where(a < 0.08, torch.zeros_like(a), a)  # 옅은 안개 지우기
        img = (torch.cat([rgb_, a], -1).cpu().numpy() * 255).round().astype(np.uint8)
        Image.fromarray(img, "RGBA").save(args.out / f"turn_{i:02d}.webp", quality=88, method=6)
    if args.ply:
        args.ply.parent.mkdir(parents=True, exist_ok=True)
        save_ply(args.ply, p)
    (args.work / "render.json").write_text(
        json.dumps({"count": args.count, "gaussians": len(p["means"]), "psnr": psnr, "train_views": ck["train_views"]})
    )
    print("rendered", args.count)


if __name__ == "__main__":
    main()
