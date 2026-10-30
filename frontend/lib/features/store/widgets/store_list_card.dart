import 'package:flutter/material.dart';

import '../../../components/channel_badge/channel_badge.dart';
import '../../../components/store_card/store_actions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/sales.dart';

/// 매장 카드: 거리 · 영업 여부 · 내 IP 굿즈 재고 수, 팝업이면 종료일. 누르면 매장 상세.
class StoreListCard extends StatelessWidget {
  const StoreListCard({super.key, required this.item, required this.onTap, this.highlight = false});

  final StoreSummary item;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final s = item.store;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: highlight ? AppColors.orange : AppColors.line, width: highlight ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(s.name, style: AppText.section.copyWith(fontSize: 15)),
                  Pill(s.kind, fg: s.isPopup ? AppColors.orange : AppColors.sub, bg: s.isPopup ? AppColors.orangeBg : AppColors.bg, size: 10),
                  if (s.popupEnds != null) Pill(s.popupEnds!, fg: AppColors.red, bg: AppColors.redBg, size: 10),
                ],
              ),
              const SizedBox(height: 4),
              Text(s.openLabel, style: AppText.caption),
              const SizedBox(height: 8),
              item.myIpStock > 0
                  ? Pill('내 IP 굿즈 재고 ${item.myIpStock}개', fg: AppColors.green, bg: AppColors.greenBg)
                  : const Pill('재고 확인 필요', fg: AppColors.sub, bg: AppColors.bg),
              const SizedBox(height: 10),
              StoreActions(store: s, height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
