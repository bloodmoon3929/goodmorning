import 'package:flutter/material.dart';

import '../../../components/channel_badge/channel_badge.dart';
import '../../../components/emoji/emoji_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/sales.dart';

/// 홈의 내 주변 재고 카드: 매장 이름 · 거리 · 내 IP 굿즈 재고 수
class NearbyStoreCard extends StatelessWidget {
  const NearbyStoreCard({super.key, required this.item, required this.onTap});

  final StoreSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = item.store;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const EmojiImage('pin', size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${s.distanceLabel} · 영업 중', style: AppText.tiny),
              const SizedBox(height: 10),
              item.myIpStock > 0
                  ? Pill('내 IP 굿즈 재고 ${item.myIpStock}개', fg: AppColors.green, bg: AppColors.greenBg)
                  : const Pill('재고 확인 필요', fg: AppColors.sub, bg: AppColors.bg),
            ],
          ),
        ),
      ),
    );
  }
}
