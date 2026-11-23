"""여러 단계가 함께 쓰는 것: SAM 3 불러오기, 텍스트로 영역 찾기, 정사각형 자르기."""

from __future__ import annotations

import os

import numpy as np


def load_sam3(threshold: float = 0.4):
    """SAM 3 이미지 모델 (Hugging Face facebook/sam3 — 접근 승인을 받은 계정으로 hf auth login 필요)"""
    import sam3
    from sam3.model.sam3_image_processor import Sam3Processor
    from sam3.model_builder import build_sam3_image_model

    bpe = os.path.join(os.path.dirname(sam3.model_builder.__file__), "assets", "bpe_simple_vocab_16e6.txt.gz")
    return Sam3Processor(build_sam3_image_model(bpe_path=bpe), confidence_threshold=threshold)


def union_mask(proc, state, prompt: str, shape: tuple[int, int]) -> np.ndarray:
    """프롬프트에 맞는 영역 전부를 합친 마스크 (0/1)"""
    o = proc.set_text_prompt(prompt=prompt, state=state)
    if len(o["scores"]) == 0:
        return np.zeros(shape, np.uint8)
    return (o["masks"][:, 0].float().amax(0).cpu().numpy() > 0.5).astype(np.uint8)


def square_around(bbox: list[int], pad: float) -> tuple[int, int, int]:
    """굿즈 상자를 가운데 둔 정사각형 (왼쪽 위 x, y, 한 변)"""
    x0, y0, x1, y1 = bbox
    side = int(max(x1 - x0, y1 - y0) * (1 + 2 * pad))
    return round((x0 + x1) / 2 - side / 2), round((y0 + y1) / 2 - side / 2), side


def crop(a: np.ndarray, sx: int, sy: int, side: int, fill) -> np.ndarray:
    """화면 밖으로 나가는 부분은 fill로 채워서 자른다"""
    h, w = a.shape[:2]
    canvas = np.full((side, side) + a.shape[2:], fill, a.dtype)
    ax0, ay0, ax1, ay1 = max(sx, 0), max(sy, 0), min(sx + side, w), min(sy + side, h)
    canvas[ay0 - sy : ay1 - sy, ax0 - sx : ax1 - sx] = a[ay0:ay1, ax0:ax1]
    return canvas
