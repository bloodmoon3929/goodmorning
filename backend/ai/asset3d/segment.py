"""2단계: SAM 3로 프레임마다 굿즈 영역(마스크)을 자르고 선명도를 잰다 → work/masks/*.png, work/masks.json

텍스트 프롬프트 하나("plush toy")로 손 · 종이 태그는 빼고 인형만 잡힌다 (README의 확인 그림 참고).
"""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image

from common import load_sam3


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--prompt", default="plush toy")
    ap.add_argument("--stride", type=int, default=2, help="n프레임마다 하나")
    args = ap.parse_args()

    frames = sorted((args.work / "frames").glob("*.jpg"))[:: args.stride]
    out = args.work / "masks"
    out.mkdir(exist_ok=True)
    proc = load_sam3()

    rows = []
    with torch.autocast("cuda", dtype=torch.bfloat16):
        for i, f in enumerate(frames):
            img = Image.open(f).convert("RGB")
            o = proc.set_text_prompt(prompt=args.prompt, state=proc.set_image(img))
            scores = o["scores"].float().cpu().numpy()
            if len(scores) == 0:
                rows.append({"frame": f.name, "score": 0.0})
                continue
            k = int(scores.argmax())
            m = (o["masks"][k, 0].float().cpu().numpy() > 0.5).astype(np.uint8)
            Image.fromarray(m * 255).save(out / f.name.replace(".jpg", ".png"))
            # 선명도: 굿즈 안쪽의 라플라시안 분산 (손으로 빨리 돌린 프레임은 흐려서 낮다)
            gray = cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2GRAY)
            lap = cv2.Laplacian(gray, cv2.CV_64F)
            inner = cv2.erode(m, np.ones((9, 9), np.uint8))
            ys, xs = np.nonzero(m)
            rows.append(
                {
                    "frame": f.name,
                    "score": float(scores[k]),
                    "area": int(m.sum()),
                    "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                    "sharpness": float(lap[inner > 0].var()) if inner.any() else 0.0,
                }
            )
            if i % 100 == 0:
                print(i, "/", len(frames), f.name, round(float(scores[k]), 3))
    (args.work / "masks.json").write_text(json.dumps(rows, indent=1))
    print("masks", sum(1 for r in rows if r.get("score", 0) > 0), "/", len(rows))


if __name__ == "__main__":
    main()
