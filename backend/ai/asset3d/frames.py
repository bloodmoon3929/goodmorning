"""1단계: 입력 → 프레임 사진 (work/frames/0001.jpg …, 가로 또는 긴 변 기준으로 줄임)

  uv run python frames.py 영상.mp4                    # 손 위 360° 영상 (ffmpeg가 휴대폰 회전 정보를 반영)
  uv run python frames.py goodmorning-capture-….zip   # 앱 '자동 촬영 가이드'가 내려준 사진 묶음 (높이 줄 → 방향 칸 순서)
  uv run python frames.py 사진폴더/                    # 사진 폴더 (파일 이름 순서)

사진 묶음은 영상처럼 이웃한 사진이 이웃한 방향이 되게 줄(ring) · 칸(sector) 순서로 번호를 붙인다 (SfM의 순서 매칭).
"""

import argparse
import io
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

from PIL import Image, ImageOps

PHOTO = {".jpg", ".jpeg", ".png", ".webp"}


def save_photos(items: list[tuple[str, bytes]], out: Path, long_side: int) -> int:
    for i, (_, data) in enumerate(items, start=1):
        img = ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert("RGB")  # 휴대폰 사진의 회전 정보 반영
        img.thumbnail((long_side, long_side), Image.LANCZOS)
        img.save(out / f"{i:04d}.jpg", quality=92)
    return len(items)


def from_zip(path: Path) -> list[tuple[str, bytes]]:
    with zipfile.ZipFile(path) as z:
        names = [n for n in z.namelist() if Path(n).suffix.lower() in PHOTO]
        order = {n: i for i, n in enumerate(sorted(names))}
        meta = [n for n in z.namelist() if n.endswith("capture.json")]
        if meta:
            # 앱 가이드: 낮게 → 중간 → 높게, 줄마다 방향 순서
            rings = {"낮게": 0, "중간": 1, "높게": 2}
            shots = json.loads(z.read(meta[0]))["shots"]
            rank = {s["file"]: (rings.get(s["ring"], 9), s["sector"]) for s in shots}
            names.sort(key=lambda n: rank.get(Path(n).name, (9, order[n])))
        else:
            names.sort()
        return [(n, z.read(n)) for n in names]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path, help="영상 · 사진 묶음(zip) · 사진 폴더")
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--width", type=int, default=720, help="영상: 가로 픽셀")
    ap.add_argument("--long-side", type=int, default=1280, help="사진: 긴 변 픽셀")
    args = ap.parse_args()
    out = args.work / "frames"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    src = args.source
    if src.is_dir():
        n = save_photos([(p.name, p.read_bytes()) for p in sorted(src.iterdir()) if p.suffix.lower() in PHOTO], out, args.long_side)
    elif src.suffix.lower() == ".zip":
        n = save_photos(from_zip(src), out, args.long_side)
    else:
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", str(src), "-vf", f"scale={args.width}:-2", "-q:v", "2", str(out / "%04d.jpg")]
        subprocess.run(cmd, check=True)
        n = len(list(out.glob("*.jpg")))
    print("frames", n)


if __name__ == "__main__":
    main()
