"""표준 3D 가우시안 .ply → 한 바퀴 회전 렌더 (배경 투명 WebP). 방법이 달라도 같은 카메라 · 같은 렌더러로 비교하려고 쓴다.

  # 우리 가우시안 스플래팅 결과 (정면 = 학습 사진 0번 카메라)
  uv run python render_ply.py output/pochita.ply --out work/cmp/gs --cams work/views/cams.json
  # SAM 3D Objects 결과 (축은 처음 한 번 보고 --up · --front로 맞춘다)
  uv run python render_ply.py output/pochita_sam3d.ply --out work/cmp/sam3d --up 0 0 1 --front 0 -1 0

.ply 속성: x y z, f_dc_0..2, (선택) f_rest_*, opacity, scale_0..2, rot_0..3 — 3DGS 표준 (SAM 3D는 f_rest 없음 = SH 0차)
"""

import argparse
import json
import math
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from gsplat import rasterization
from PIL import Image
from plyfile import PlyData

from common import largest_cluster
from render import look_at, rotate


def load_ply(path: Path) -> dict[str, torch.Tensor]:
    v = PlyData.read(str(path))["vertex"]
    names = v.data.dtype.names
    col = lambda k: np.asarray(v[k], np.float32)
    rest = sorted([n for n in names if n.startswith("f_rest_")], key=lambda n: int(n.split("_")[-1]))
    n = len(v.data)
    sh_n = len(rest) // 3
    shn = np.stack([col(k) for k in rest], 1).reshape(n, 3, sh_n).transpose(0, 2, 1) if rest else np.zeros((n, 0, 3), np.float32)
    return {
        "means": torch.tensor(np.stack([col("x"), col("y"), col("z")], 1)),
        "sh0": torch.tensor(np.stack([col(f"f_dc_{i}") for i in range(3)], 1))[:, None, :],
        "shN": torch.tensor(shn),
        "opacities": torch.tensor(col("opacity")),
        "scales": torch.tensor(np.stack([col(f"scale_{i}") for i in range(3)], 1)),
        "quats": torch.tensor(np.stack([col(f"rot_{i}") for i in range(4)], 1)),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("ply", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--cams", type=Path, default=None, help="학습 사진 카메라(cams.json): 0번 카메라를 정면 · 위쪽 기준으로")
    ap.add_argument("--up", type=float, nargs=3, default=None, help="위쪽 방향 (cams가 없을 때)")
    ap.add_argument("--front", type=float, nargs=3, default=None, help="물체 중심에서 정면 카메라 쪽 방향 (cams가 없을 때)")
    ap.add_argument(
        "--toward-origin", action="store_true", help="정면 = 물체 중심에서 원점(입력 사진의 카메라) 쪽 (SAM 3D의 카메라 좌표 .ply)"
    )
    ap.add_argument("--elev", type=float, default=10, help="--front를 쓸 때 위에서 내려다보는 각도(도)")
    ap.add_argument("--count", type=int, default=72)
    ap.add_argument("--size", type=int, default=400)
    ap.add_argument("--fov", type=float, default=30, help="세로 화각(도). 물체가 화면의 이 정도를 채우게 거리를 정한다")
    ap.add_argument("--fill", type=float, default=0.75, help="물체가 화면을 채우는 비율")
    args = ap.parse_args()
    dev = "cuda"
    args.out.mkdir(parents=True, exist_ok=True)

    g = load_ply(args.ply)
    # 서로 붙어 있는 가장 큰 덩어리만 (두 방법에 같게)
    keep = torch.from_numpy(largest_cluster(g["means"].numpy(), torch.sigmoid(g["opacities"]).numpy()))
    g = {k: v[keep].to(dev) for k, v in g.items()}
    op = torch.sigmoid(g["opacities"])
    xyz = g["means"][op > 0.3].cpu().numpy()
    center = (np.percentile(xyz, 1, 0) + np.percentile(xyz, 99, 0)) / 2
    radius = float(np.percentile(np.linalg.norm(xyz - center, axis=1), 99))

    if args.cams:
        c0 = json.loads(args.cams.read_text())[0]
        vm0 = np.asarray(c0["viewmat"])
        up = -vm0[:3, :3].T @ np.array([0.0, 1.0, 0.0])
        eye0 = -vm0[:3, :3].T @ vm0[:3, 3]
        front = (eye0 - center) / np.linalg.norm(eye0 - center)
    elif args.toward_origin:
        if args.up is None:
            raise SystemExit("--toward-origin에는 --up이 필요합니다")
        up = np.asarray(args.up, float) / np.linalg.norm(args.up)
        front = -center / np.linalg.norm(center)  # 입력 사진을 찍은 방향 그대로 (높이 포함)
    else:
        if args.up is None or args.front is None:
            raise SystemExit("--cams, --toward-origin 또는 --up · --front가 필요합니다")
        up = np.asarray(args.up, float) / np.linalg.norm(args.up)
        f = np.asarray(args.front, float)
        f = f - up * (up @ f)
        f /= np.linalg.norm(f)
        e = math.radians(args.elev)
        front = f * math.cos(e) + up * math.sin(e)
    # 물체(반지름 radius)가 화면의 fill만큼 차는 거리
    fov = math.radians(args.fov)
    dist = radius / (math.tan(fov / 2) * args.fill)
    focal = args.size / 2 / math.tan(fov / 2)
    K = torch.tensor([[focal, 0, args.size / 2], [0, focal, args.size / 2], [0, 0, 1]], device=dev, dtype=torch.float32)
    deg = round(math.sqrt(g["shN"].shape[1] + 1)) - 1
    colors = torch.cat([g["sh0"], g["shN"]], 1)
    for i in range(args.count):
        eye = center + rotate(front * dist, up, 2 * math.pi * i / args.count)
        vm = torch.tensor(look_at(eye, center, up), device=dev, dtype=torch.float32)
        with torch.no_grad():
            out, alpha, _ = rasterization(
                g["means"],
                F.normalize(g["quats"], dim=-1),
                torch.exp(g["scales"]),
                op,
                colors,
                vm[None],
                K[None],
                args.size,
                args.size,
                sh_degree=deg,
                packed=False,
                rasterize_mode="antialiased",
            )
        a = alpha[0].clamp(0, 1)
        rgb = (out[0] / a.clamp_min(1e-4)).clamp(0, 1)
        a = torch.where(a < 0.08, torch.zeros_like(a), a)
        img = (torch.cat([rgb, a], -1).cpu().numpy() * 255).round().astype(np.uint8)
        Image.fromarray(img, "RGBA").save(args.out / f"turn_{i:02d}.webp", quality=88, method=6)
    (args.out / "render.json").write_text(json.dumps({"ply": str(args.ply), "gaussians": len(op), "count": args.count}))
    print("rendered", args.count, "gaussians", len(op))


if __name__ == "__main__":
    main()
