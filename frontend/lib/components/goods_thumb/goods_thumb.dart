import 'package:flutter/material.dart';

import '../emoji/emoji_image.dart';

/// 상품 · IP · 캐릭터 사진 자리. 파스텔 배경 위에 이모지 그림.
/// 목록에는 작은 크기, 상품 상세에는 큰 크기로 쓴다.
class GoodsThumb extends StatelessWidget {
  const GoodsThumb({
    super.key,
    required this.emoji,
    required this.bg,
    this.width,
    this.height,
    this.size = 72,
    this.radius = 14,
    this.emojiScale = 0.56,
    this.circle = false,
  });

  final String emoji;
  final Color bg;
  final double? width;
  final double? height;
  final double size;
  final double radius;
  final double emojiScale;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: bg, shape: circle ? BoxShape.circle : BoxShape.rectangle, borderRadius: circle ? null : BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: EmojiImage(emoji, size: (w < h ? w : h) * emojiScale),
    );
  }
}
