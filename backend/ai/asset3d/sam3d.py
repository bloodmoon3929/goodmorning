"""SAM 3D Objects: 사진 한 장 + SAM 3 마스크 → 3D 가우시안 (.ply) — 가우시안 스플래팅(영상 여러 장)과 비교용

이 스크립트만 SAM 3D Objects 전용 환경에서 돈다 (torch 2.5.1 + cu121, pytorch3d, kaolin — uv 환경과 다름):

  git clone https://github.com/facebookresearch/sam-3d-objects ~/sam-3d-objects   # 설치는 그 저장소 doc/setup.md
  # 가중치: huggingface.co/facebook/sam-3d-objects 접근 승인 후 checkpoints/hf 에
  conda run -n sam3d-objects python sam3d.py --image work/frames/0001.jpg --mask work/masks/0001.png --ply output/pochita_sam3d.ply

결과: <이름>.ply = 입력 사진의 카메라 좌표(0° = 사진 방향), <이름>_object.ply = 물체 자체 좌표.
.ply는 render_ply.py로 가우시안 스플래팅과 같은 카메라 · 같은 렌더러로 돌려 compare.py로 나란히 놓는다.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, default=Path.home() / "sam-3d-objects")
    ap.add_argument("--tag", default="hf", help="checkpoints/<tag>/pipeline.yaml")
    ap.add_argument("--image", type=Path, required=True, help="굿즈가 잘 보이는 사진 한 장")
    ap.add_argument("--mask", type=Path, required=True, help="그 사진의 굿즈 마스크 (흰색 = 굿즈, segment.py 결과)")
    ap.add_argument("--ply", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    image_path, mask_path, ply_path = args.image.resolve(), args.mask.resolve(), args.ply.resolve()
    sys.path.insert(0, str(args.repo / "notebook"))
    os.chdir(args.repo)  # 설정 파일이 저장소 기준 경로를 쓴다
    from inference import Inference, make_scene

    image = np.asarray(Image.open(image_path).convert("RGB"))
    mask = np.asarray(Image.open(mask_path).convert("L")) > 127
    started = time.time()
    model = Inference(str(args.repo / "checkpoints" / args.tag / "pipeline.yaml"), compile=False)
    loaded = time.time()
    out = model(image, mask, seed=args.seed)
    done = time.time()

    ply_path.parent.mkdir(parents=True, exist_ok=True)
    # 입력 사진의 카메라 좌표로 옮긴 것 (추정한 회전 · 위치 · 크기 적용) → 0° 렌더가 입력 사진 방향
    make_scene(out).save_ply(str(ply_path))
    # 물체 자체 좌표 (참고용)
    out["gs"].save_ply(str(ply_path.with_name(ply_path.stem + "_object.ply")))
    info = {
        "image": str(image_path),
        "mask": str(mask_path),
        "seed": args.seed,
        "load_sec": round(loaded - started, 1),
        "infer_sec": round(done - loaded, 1),
        "gaussians": int(out["gs"].get_xyz.shape[0]),
        "keys": sorted(out.keys()),
    }
    for k in ("rotation", "translation", "scale"):
        if k in out and hasattr(out[k], "tolist"):
            info[k] = out[k].detach().cpu().tolist() if hasattr(out[k], "detach") else out[k].tolist()
    ply_path.with_suffix(".json").write_text(json.dumps(info, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps({k: v for k, v in info.items() if k not in ("rotation", "translation", "scale")}))


if __name__ == "__main__":
    main()
