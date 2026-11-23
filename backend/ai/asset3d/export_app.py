"""7단계: 앱 '내 방' 탭에 넣을 그림 · manifest.json 내보내기 (frontend/assets/room/<id>/)

capture_NN.jpg  영상 전체를 count 구간으로 나눠 구간마다 가장 선명한 프레임 (굿즈 중심 4:5)
segment_NN.jpg  같은 프레임에 SAM 3 마스크 표시 (배경은 어둡게, 윤곽은 민트)
turn_NN.webp    render.py가 만든 회전 그림 (이미 이 폴더에 있어야 함)
manifest.json   앱이 읽는 정보 (장 수, 방법, 가우시안 수, PSNR)
"""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

MINT = np.array([34, 199, 160], np.float32)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--id", default="pochita")
    ap.add_argument("--name", default="포치타 인형")
    ap.add_argument("--video", default="20261123_091242.mp4")
    ap.add_argument("--fps", type=int, default=120)
    ap.add_argument("--prompt", default="plush toy")
    ap.add_argument("--count", type=int, default=36)
    ap.add_argument("--size", type=int, nargs=2, default=(400, 500))
    args = ap.parse_args()

    rows = [r for r in json.loads((args.work / "masks.json").read_text()) if r.get("score", 0) > 0.6]
    picks = [rows[max(b, key=lambda i: rows[i]["sharpness"])] for b in np.array_split(np.arange(len(rows)), args.count)]
    tw, th = args.size
    for k, r in enumerate(picks):
        img = np.asarray(Image.open(args.work / "frames" / r["frame"]).convert("RGB")).astype(np.float32)
        m = (np.asarray(Image.open(args.work / "masks" / r["frame"].replace(".jpg", ".png"))) > 127).astype(np.uint8)
        h, w = m.shape
        ch = int(w * th / tw)
        cy = int(np.clip((r["bbox"][1] + r["bbox"][3]) / 2 - ch / 2, 0, h - ch))
        part = (slice(cy, cy + ch), slice(0, w))
        Image.fromarray(img[part].astype(np.uint8)).resize((tw, th), Image.LANCZOS).save(args.out / f"capture_{k:02d}.jpg", quality=80)

        gray = img.mean(2, keepdims=True)
        bg = (0.35 * gray + 0.05 * img) * 0.55 + np.array([10, 40, 36], np.float32) * 0.45
        seg = np.where(m[..., None] > 0, img, bg)
        edge = cv2.dilate(m, np.ones((7, 7), np.uint8)) - m
        seg[edge > 0] = MINT
        glow = cv2.GaussianBlur(edge.astype(np.float32), (0, 0), 6)[..., None]
        seg = np.where(m[..., None] > 0, seg, seg * (1 - 0.6 * glow) + MINT * 0.6 * glow)
        Image.fromarray(seg[part].clip(0, 255).astype(np.uint8)).resize((tw, th), Image.LANCZOS).save(
            args.out / f"segment_{k:02d}.jpg", quality=80
        )

    frames = len(list((args.work / "frames").glob("*.jpg")))
    r = json.loads((args.work / "render.json").read_text())
    manifest = {
        "id": args.id,
        "name": args.name,
        "source": args.video,
        "video": {"seconds": round(frames / args.fps, 1), "fps": args.fps, "frames": frames},
        "capture": {"count": len(picks)},
        "segment": {"count": len(picks), "model": "SAM 3", "prompt": args.prompt},
        "turntable": {"count": r["count"], "front": 0},
        "recon": {
            "method": "3D 가우시안 스플래팅 (gsplat)",
            "poses": "COLMAP SfM · ALIKED + LightGlue 매칭",
            "views": r["train_views"],
            "gaussians": r["gaussians"],
            "psnr": r["psnr"],
        },
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
