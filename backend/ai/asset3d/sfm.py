"""3단계: 카메라 자세 추정 (SfM) — ALIKED 특징점 + LightGlue 매칭 → COLMAP 기하 검증 · 증분 복원 → work/sfm/sparse/N

- 손으로 굿즈를 돌리면 배경은 굿즈와 따로 움직이므로, 특징점은 SAM 3 마스크 안에서만 뽑는다
  ("굿즈는 가만히 있고 카메라가 주위를 돈다"로 풀린다).
- 털 인형처럼 무늬가 약하면 SIFT로는 조각나서(4조각, 최대 76장) 학습된 특징점 · 매칭기를 쓴다.
- 짝: 영상 순서로 가까운 프레임 + 띄엄띄엄 고른 프레임끼리 전부 (한 바퀴 돌아 처음과 이어지게)
"""

import argparse
import json
import shutil
from pathlib import Path

import cv2
import kornia.feature as KF
import numpy as np
import pycolmap
import torch
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--every", type=int, default=2, help="분할한 프레임 중 n장마다 하나")
    ap.add_argument("--window", type=int, default=10)
    ap.add_argument("--global-every", type=int, default=8)
    ap.add_argument("--max-kp", type=int, default=4096)
    args = ap.parse_args()
    dev = torch.device("cuda")

    rows = [r for r in json.loads((args.work / "masks.json").read_text()) if r.get("score", 0) > 0.6][:: args.every]
    sharp = np.array([r["sharpness"] for r in rows])
    rows = [r for r in rows if r["sharpness"] >= np.percentile(sharp, 15)]  # 흐린 프레임 15% 제외
    names = [r["frame"] for r in rows]

    sfm = args.work / "sfm"
    if sfm.exists():
        shutil.rmtree(sfm)
    img_dir, out = sfm / "images", sfm / "sparse"
    img_dir.mkdir(parents=True)
    out.mkdir()
    for n in names:
        (img_dir / n).symlink_to((args.work / "frames" / n).resolve())
    db_path = sfm / "database.db"
    pycolmap.Database.open(db_path).close()
    reader = pycolmap.ImageReaderOptions()
    reader.camera_model = "SIMPLE_RADIAL"
    pycolmap.import_images(db_path, img_dir, camera_mode=pycolmap.CameraMode.SINGLE, options=reader)
    db = pycolmap.Database.open(db_path)
    ids = {im.name: im.image_id for im in db.read_all_images()}

    aliked = KF.ALIKED.from_pretrained("aliked-n16", max_num_keypoints=args.max_kp, device=dev).eval()
    matcher = KF.LightGlueMatcher("aliked").to(dev).eval()
    feats = {}
    with torch.inference_mode():
        for n in names:
            img = Image.open(img_dir / n).convert("RGB")
            w, h = img.size
            scale = 1024 / max(w, h)
            small = img.resize((round(w * scale), round(h * scale)), Image.BILINEAR)
            t = torch.from_numpy(np.array(small)).permute(2, 0, 1).float().div(255)[None].to(dev)
            f = aliked(t)[0]
            kp = f.keypoints / scale
            m = np.asarray(Image.open(args.work / "masks" / n.replace(".jpg", ".png"))) > 127
            m = cv2.erode(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0  # 윤곽 바로 위(배경과 섞인 곳)는 빼기
            xy = kp.round().long().cpu().numpy()
            xy[:, 0] = xy[:, 0].clip(0, w - 1)
            xy[:, 1] = xy[:, 1].clip(0, h - 1)
            keep = torch.from_numpy(m[xy[:, 1], xy[:, 0]]).to(dev)
            feats[n] = (kp[keep], f.descriptors[keep], (h, w))
            db.write_keypoints(ids[n], kp[keep].cpu().numpy().astype(np.float32))
        print("images", len(names), "keypoints per image (median)", int(np.median([len(v[0]) for v in feats.values()])))

        pairs = set()
        for i in range(len(names)):
            for k in [*range(1, args.window + 1), 16, 32]:
                if i + k < len(names):
                    pairs.add((i, i + k))
        glob = list(range(0, len(names), args.global_every))
        pairs |= {(a, b) for a in glob for b in glob if a < b}

        lines = []
        for a, b in sorted(pairs):
            ka, da, hwa = feats[names[a]]
            kb, dbb, hwb = feats[names[b]]
            if len(ka) < 8 or len(kb) < 8:
                continue
            la = KF.laf_from_center_scale_ori(ka[None], torch.ones(1, len(ka), 1, 1, device=dev))
            lb = KF.laf_from_center_scale_ori(kb[None], torch.ones(1, len(kb), 1, 1, device=dev))
            _, idx = matcher(da, dbb, la, lb, hw1=torch.tensor(hwa), hw2=torch.tensor(hwb))
            if len(idx) < 15:
                continue
            db.write_matches(ids[names[a]], ids[names[b]], idx.cpu().numpy().astype(np.uint32))
            lines.append(f"{names[a]} {names[b]}")
    db.close()
    (sfm / "pairs.txt").write_text("\n".join(lines))
    print("pairs", len(pairs), "matched", len(lines))
    pycolmap.verify_matches(db_path, sfm / "pairs.txt")

    opts = pycolmap.IncrementalPipelineOptions()
    opts.min_model_size = 20
    recs = pycolmap.incremental_mapping(db_path, img_dir, out, options=opts)
    best = max(recs, key=lambda k: recs[k].num_reg_images())
    for k, r in recs.items():
        print(
            "model",
            k,
            r.num_reg_images(),
            "/",
            len(names),
            "points",
            r.num_points3D(),
            "err",
            round(r.compute_mean_reprojection_error(), 3),
        )
    (sfm / "best.txt").write_text(str(out / str(best)))
    print("best", out / str(best))


if __name__ == "__main__":
    main()
