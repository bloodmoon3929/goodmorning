"""다른 방법의 회전 렌더를 앱 에셋에 더한다 (앱 '내 방'의 3D 단계에서 방법을 바꿔 비교)

  uv run python export_compare.py --out ../../../frontend/assets/room/pochita --id sam3d \\
      --label "SAM 3D (사진 1장)" --method "SAM 3D Objects (사진 1장 → 3D)" \\
      --turns work/cmp/sam3d --info output/pochita_sam3d.json

<out>/<id>_turn_NN.webp 로 복사하고 manifest.json의 "compare"에 한 줄 더한다 (같은 id면 바꾼다).
"""

import argparse
import json
import shutil
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--id", required=True)
    ap.add_argument("--label", required=True)
    ap.add_argument("--method", required=True)
    ap.add_argument("--turns", type=Path, required=True)
    ap.add_argument("--info", type=Path, required=True, help="sam3d.py가 남긴 json (추론 시간 · 가우시안 수)")
    ap.add_argument("--views", type=int, default=1)
    args = ap.parse_args()

    frames = sorted(args.turns.glob("turn_*.webp"))
    for old in args.out.glob(f"{args.id}_turn_*.webp"):
        old.unlink()
    for i, f in enumerate(frames):
        shutil.copy(f, args.out / f"{args.id}_turn_{i:02d}.webp")
    info = json.loads(args.info.read_text(encoding="utf-8"))
    manifest_path = args.out / "manifest.json"
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    entry = {
        "id": args.id,
        "label": args.label,
        "method": args.method,
        "prefix": f"{args.id}_turn_",
        "count": len(frames),
        "views": args.views,
        "gaussians": info["gaussians"],
        "seconds": info["infer_sec"],
    }
    m["compare"] = [c for c in m.get("compare", []) if c["id"] != args.id] + [entry]
    manifest_path.write_text(json.dumps(m, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps(entry, ensure_ascii=False))


if __name__ == "__main__":
    main()
