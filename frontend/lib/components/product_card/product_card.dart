import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../channel_badge/channel_badge.dart';
import '../external_move/login_gate.dart';
import '../goods_thumb/goods_thumb.dart';

/// 상품 카드 (사진 · IP와 캐릭터 · 상품명 · 배지 · ♡). 홈 신상품, IP 화면, 비슷한 굿즈에서 쓴다.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.item, required this.onTap});

  final ProductSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.55,
                child: GoodsThumb(emoji: p.emoji, bg: p.bg, width: double.infinity, height: double.infinity, emojiScale: 0.6),
              ),
              Positioned(right: 2, top: 2, child: FavoriteButton(productId: p.id)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny),
          const SizedBox(height: 2),
          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
          const SizedBox(height: 6),
          ChannelBadges(item.channels),
        ],
      ),
    );
  }
}

/// 찜(♡). 바뀐 위젯만 다시 그린다 — 이 버튼만 상태를 듣는다.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.productId, this.size = 22, this.color = AppColors.sub});

  final String productId;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final on = state.favorites.contains(productId);
    return IconButton(
      tooltip: on ? '찜 해제' : '찜하기',
      onPressed: () async {
        if (!await ensureMember(context, '찜')) return;
        state.toggleFavorite(productId);
      },
      icon: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: size, color: on ? AppColors.red : color),
    );
  }
}

/// 목록형 결과 행 (검색 결과 · 사진 검색 결과 · 품목 목록)
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.item, required this.onTap, this.chip, this.trailing, this.dim = false, this.thumb = 76});

  final ProductSummary item;
  final VoidCallback onTap;
  final Widget? chip; // 버전 칩
  final Widget? trailing; // 유사도
  final bool dim;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: 10),
        child: Opacity(
          opacity: dim ? 0.6 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoodsThumb(emoji: p.emoji, bg: p.bg, size: thumb, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny),
                        ),
                        ?trailing,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        ?chip,
                        ChannelBadges(item.channels, axis: Axis.horizontal),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
