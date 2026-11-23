"""4단계: 학습용 사진 만들기 → work/views/{rgb,mask,ignore}/NNN.png, cams.json, points.npz

- SfM에 들어간 프레임 중 count장을 영상 순서대로 고르게 고른다
- 굿즈를 가운데 둔 정사각형으로 자르고(초점거리 · 중심점도 같이 옮김) 배경은 흰색
- 손 · 종이 태그가 굿즈를 가린 곳은 ignore로 표시 → 학습에서 빼서 그 자리에 구멍이 생기지 않게
"""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import pycolmap
import torch
from PIL import Image

from common import crop, load_sam3, square_around, union_mask


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--count", type=int, default=160)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--pad", type=float, default=0.15)
    args = ap.parse_args()

    rec = pycolmap.Reconstruction((args.work / "sfm" / "best.txt").read_text().strip())
    cam = next(iter(rec.cameras.values()))
    f, cx, cy = cam.params[0], cam.params[1], cam.params[2]  # SIMPLE_RADIAL: 왜곡 계수는 아주 작아 무시
    ims = sorted(rec.images.values(), key=lambda i: i.name)
    picks = [ims[int(i)] for i in np.linspace(0, len(ims) - 1, min(args.count, len(ims))).round()]
    rows = {r["frame"]: r for r in json.loads((args.work / "masks.json").read_text())}
    proc = load_sam3()

    out = args.work / "views"
    for d in ("rgb", "mask", "ignore"):
        (out / d).mkdir(parents=True, exist_ok=True)
    cams = []
    with torch.autocast("cuda", dtype=torch.bfloat16):
        for k, im in enumerate(picks):
            img = Image.open(args.work / "frames" / im.name).convert("RGB")
            rgb = np.asarray(img)
            h, w = rgb.shape[:2]
            obj = (np.asarray(Image.open(args.work / "masks" / im.name.replace(".jpg", ".png"))) > 127).astype(np.uint8)
            state = proc.set_image(img)
            occ = np.maximum(union_mask(proc, state, "hand", (h, w)), union_mask(proc, state, "paper tag", (h, w)))
            ignore = (cv2.dilate(occ, np.ones((15, 15), np.uint8)) > 0) & (obj == 0)

            sx, sy, side = square_around(rows[im.name]["bbox"], args.pad)
            outside = crop(np.ones((h, w), np.uint8), sx, sy, side, 0) == 0  # 화면 밖: 굿즈인지 알 수 없으니 ignore
            m = crop(obj, sx, sy, side, 0)
            ig = crop(ignore.astype(np.uint8), sx, sy, side, 0).astype(bool) | outside
            c = crop(rgb, sx, sy, side, 255)
            c[m == 0] = 255

            name = f"{k:03d}.png"
            size = (args.size, args.size)
            Image.fromarray(c).resize(size, Image.LANCZOS).save(out / "rgb" / name)
            Image.fromarray(m * 255).resize(size, Image.BILINEAR).save(out / "mask" / name)
            Image.fromarray(ig.astype(np.uint8) * 255).resize(size, Image.NEAREST).save(out / "ignore" / name)
            s = args.size / side
            vm = np.eye(4)
            vm[:3, :4] = im.cam_from_world().matrix()
            cams.append(
                {
                    "view": name,
                    "frame": im.name,
                    "K": [[f * s, 0, (cx - sx) * s], [0, f * s, (cy - sy) * s], [0, 0, 1]],
                    "viewmat": vm.tolist(),
                }
            )
            if k % 40 == 0:
                print(k, "/", len(picks), im.name)
    np.savez(
        out / "points.npz",
        xyz=np.array([p.xyz for p in rec.points3D.values()]),
        rgb=np.array([p.color for p in rec.points3D.values()]) / 255.0,
    )
    (out / "cams.json").write_text(json.dumps(cams))
    print("views", len(cams))


if __name__ == "__main__":
    main()
