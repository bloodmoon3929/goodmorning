"""5단계: gsplat으로 3D 가우시안 스플래팅 학습 → work/gaussians.pt

- 시작 점: SfM 점 중 학습 사진 대부분에서 마스크 안에 들어오는 것 + 그 범위 안 무작위 점
- 손실: 색(L1 0.8 + SSIM 0.2) + 윤곽(alpha ↔ SAM 3 마스크, 0.5). 손 · 태그가 가린 곳(ignore)은 빼고 계산
- holdout장마다 한 장은 학습에 쓰지 않고 확인용(PSNR)으로 둔다
"""

import argparse
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from gsplat import rasterization
from gsplat.strategy import DefaultStrategy
from PIL import Image

C0 = 0.28209479177387814  # SH 0차 계수


def ssim(x: torch.Tensor, y: torch.Tensor) -> torch.Tensor:
    k = 11
    g = torch.exp(-((torch.arange(k, device=x.device) - k // 2) ** 2) / (2 * 1.5**2))
    g = (g / g.sum())[:, None] @ (g / g.sum())[None, :]
    w = g.expand(3, 1, k, k)

    def f(a):
        return F.conv2d(a, w, padding=k // 2, groups=3)

    mx, my = f(x), f(y)
    sxx, syy, sxy = f(x * x) - mx**2, f(y * y) - my**2, f(x * y) - mx * my
    c1, c2 = 0.01**2, 0.03**2
    return (((2 * mx * my + c1) * (2 * sxy + c2)) / ((mx**2 + my**2 + c1) * (sxx + syy + c2))).mean()


def holdout_ids(n: int, every: int) -> list[int]:
    return [i for i in range(n) if every > 0 and i % every == every // 2]


def load_views(views: Path):
    cams = json.loads((views / "cams.json").read_text())

    def load(d, name):
        return np.asarray(Image.open(views / d / name)).astype(np.float32) / 255.0

    rgb = np.stack([load("rgb", c["view"])[..., :3] for c in cams])
    mask = np.stack([load("mask", c["view"]) for c in cams])
    ignore = np.stack([load("ignore", c["view"]) for c in cams]) > 0.5
    return cams, rgb, mask, ignore


def render(params, viewmat, K, w, h, sh_degree=3):
    return rasterization(
        params["means"],
        F.normalize(params["quats"], dim=-1),
        torch.exp(params["scales"]),
        torch.sigmoid(params["opacities"]),
        torch.cat([params["sh0"], params["shN"]], 1),
        viewmat[None],
        K[None],
        w,
        h,
        sh_degree=sh_degree,
        backgrounds=torch.ones(1, 3, device=viewmat.device),
        packed=False,
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=Path("work"))
    ap.add_argument("--steps", type=int, default=15000)
    ap.add_argument("--init-points", type=int, default=30000)
    ap.add_argument("--holdout", type=int, default=8)
    args = ap.parse_args()
    dev = "cuda"
    torch.manual_seed(0)
    np.random.seed(0)

    cams, rgb, mask, ignore = load_views(args.work / "views")
    n, h, w = mask.shape
    viewmats = torch.tensor(np.array([c["viewmat"] for c in cams]), device=dev, dtype=torch.float32)
    ks = torch.tensor(np.array([c["K"] for c in cams]), device=dev, dtype=torch.float32)

    # 시작 점: 5장 이상에서 보이고, 보이는 사진의 80% 이상에서 마스크 안인 SfM 점
    pz = np.load(args.work / "views" / "points.npz")
    xyz, col = pz["xyz"], pz["rgb"]
    hom = np.concatenate([xyz, np.ones((len(xyz), 1))], 1)
    inside = np.zeros(len(xyz))
    seen = np.zeros(len(xyz))
    for i in range(n):
        cam = (viewmats[i].cpu().numpy() @ hom.T)[:3]
        u, v = ((ks[i].cpu().numpy() @ cam)[:2] / np.maximum(cam[2], 1e-6)).round().astype(int)
        ok = np.where((cam[2] > 0) & (u >= 0) & (u < w) & (v >= 0) & (v < h))[0]
        ok = ok[~ignore[i, v[ok], u[ok]]]
        seen[ok] += 1
        inside[ok] += mask[i, v[ok], u[ok]] > 0.5
    keep = (seen >= 5) & (inside / np.maximum(seen, 1) > 0.8)
    xyz, col = xyz[keep], col[keep]
    lo, hi = np.percentile(xyz, 1, 0), np.percentile(xyz, 99, 0)
    p = np.concatenate([xyz, np.random.uniform(lo, hi, (args.init_points, 3))]).astype(np.float32)
    c = np.concatenate([col, np.full((args.init_points, 3), 0.7)]).astype(np.float32)
    center = np.median(xyz, 0)
    centers = np.stack([np.linalg.inv(m)[:3, 3] for m in viewmats.cpu().numpy()])
    scene_scale = float(np.linalg.norm(centers - center, axis=1).mean())
    print(f"views {n}, SfM points kept {keep.sum()}/{len(keep)}, init {len(p)}, scene_scale {scene_scale:.3f}")

    pt = torch.tensor(p, device=dev)
    d = torch.cdist(pt[:4096], pt).topk(4, largest=False).values[:, 1:].mean()
    params = torch.nn.ParameterDict(
        {
            "means": torch.nn.Parameter(pt),
            "scales": torch.nn.Parameter(torch.log(d.clamp_min(1e-4)).repeat(len(p), 3)),
            "quats": torch.nn.Parameter(F.normalize(torch.rand(len(p), 4, device=dev), dim=-1)),
            "opacities": torch.nn.Parameter(torch.logit(torch.full((len(p),), 0.3, device=dev))),
            "sh0": torch.nn.Parameter(((torch.tensor(c, device=dev) - 0.5) / C0)[:, None, :]),
            "shN": torch.nn.Parameter(torch.zeros(len(p), 15, 3, device=dev)),
        }
    )
    lrs = {"means": 1.6e-4 * scene_scale, "scales": 5e-3, "quats": 1e-3, "opacities": 5e-2, "sh0": 2.5e-3, "shN": 2.5e-3 / 20}
    optimizers = {k: torch.optim.Adam([params[k]], lr=lr, eps=1e-15) for k, lr in lrs.items()}
    sched = torch.optim.lr_scheduler.ExponentialLR(optimizers["means"], gamma=0.01 ** (1.0 / args.steps))
    strategy = DefaultStrategy(refine_stop_iter=int(args.steps * 0.6), reset_every=3000)
    strategy.check_sanity(params, optimizers)
    sstate = strategy.initialize_state(scene_scale=scene_scale)

    t_rgb = torch.tensor(rgb, device=dev)
    t_mask = torch.tensor(mask, device=dev)
    t_valid = torch.tensor(~ignore, device=dev, dtype=torch.float32)
    hold = holdout_ids(n, args.holdout)
    train = [i for i in range(n) if i not in hold]

    for step in range(args.steps):
        i = train[np.random.randint(len(train))]
        out, alpha, info = render(params, viewmats[i], ks[i], w, h, sh_degree=min(3, step // 1000))
        pred, a, valid = out[0], alpha[0, ..., 0], t_valid[i]
        gt = torch.where(valid[..., None] > 0, t_rgb[i], pred.detach())  # 가린 곳은 정답 대신 예측 그대로 → 손실 0
        l1 = ((pred - gt).abs().mean(-1) * valid).sum() / valid.sum()
        ss = 1 - ssim(pred.permute(2, 0, 1)[None], gt.permute(2, 0, 1)[None])
        la = ((a - t_mask[i]).abs() * valid).sum() / valid.sum()
        loss = 0.8 * l1 + 0.2 * ss + 0.5 * la
        strategy.step_pre_backward(params, optimizers, sstate, step, info)
        loss.backward()
        for o in optimizers.values():
            o.step()
            o.zero_grad(set_to_none=True)
        sched.step()
        strategy.step_post_backward(params, optimizers, sstate, step, info, packed=False)
        if step % 1000 == 0 or step == args.steps - 1:
            print(f"step {step} loss {loss.item():.4f} gaussians {len(params['means'])}")

    psnrs = []
    with torch.no_grad():
        for i in hold:
            out, _, _ = render(params, viewmats[i], ks[i], w, h)
            mse = ((out[0] - t_rgb[i]) ** 2).mean(-1)[t_valid[i] > 0].mean()
            psnrs.append(float(-10 * torch.log10(mse)))
    print("holdout PSNR", round(float(np.mean(psnrs)), 2), "views", len(hold))
    state = {k: v.detach().cpu() for k, v in params.items()}
    torch.save({"params": state, "center": center, "train_views": len(train), "holdout": args.holdout}, args.work / "gaussians.pt")


if __name__ == "__main__":
    main()
