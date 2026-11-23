"""방법별 회전 렌더를 같은 각도로 나란히 놓은 비교 그림 (발표 · README용)

  uv run python compare.py --row "가우시안 스플래팅 (영상 160장)" work/cmp/gs --row "SAM 3D Objects (사진 1장)" work/cmp/sam3d \\
      --angles 0 45 90 135 180 225 270 315 --out output/compare.png
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
]


def font(size: int):
    for f in FONT_CANDIDATES:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--row", nargs=2, action="append", metavar=("LABEL", "DIR"), required=True)
    ap.add_argument("--angles", type=int, nargs="+", default=[0, 45, 90, 135, 180, 225, 270, 315])
    ap.add_argument("--cell", type=int, default=220)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    label_w, head_h, c = 260, 40, args.cell
    W = label_w + c * len(args.angles)
    H = head_h + c * len(args.row)
    canvas = Image.new("RGBA", (W, H), (255, 249, 240, 255))
    d = ImageDraw.Draw(canvas)
    f_small, f_label = font(18), font(20)
    for j, ang in enumerate(args.angles):
        d.text((label_w + j * c + c // 2, head_h // 2), f"{ang}°", fill=(24, 40, 68), font=f_small, anchor="mm")
    for i, (label, folder) in enumerate(args.row):
        frames = sorted(Path(folder).glob("turn_*.webp"))
        n = len(frames)
        y = head_h + i * c
        d.multiline_text((16, y + c // 2), label.replace(" (", "\n("), fill=(24, 40, 68), font=f_label, anchor="lm")
        for j, ang in enumerate(args.angles):
            if n == 1 and ang % 360 != 0:
                continue  # 사진 한 장(입력)은 0° 칸에만
            im = Image.open(frames[round(ang / 360 * n) % n]).convert("RGBA").resize((c, c))
            canvas.alpha_composite(im, (label_w + j * c, y))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(args.out)
    print("saved", args.out)


if __name__ == "__main__":
    main()
