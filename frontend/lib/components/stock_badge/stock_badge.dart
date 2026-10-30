import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sales.dart';
import '../channel_badge/channel_badge.dart';

(Color, Color) stockColors(StockStatus s) => switch (s) {
  StockStatus.many => (AppColors.green, AppColors.greenBg),
  StockStatus.few => (AppColors.amber, AppColors.amberBg),
  StockStatus.none => (AppColors.red, AppColors.redBg),
  StockStatus.check => (AppColors.sub, AppColors.bg),
};

/// 재고 많음 · 적음 · 없음 · 확인 필요 + 누가 · 언제 확인했는지.
/// 확인한 지 48시간이 지나면 "확인 필요"(회색)로 보인다.
class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key, this.source, this.alignEnd = true, this.size = 12});

  final StockStatus status;
  final String? source; // 사장님 확인 · 2시간 전
  final bool alignEnd;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = stockColors(status);
    final badge = Pill(status.label, fg: fg, bg: bg, size: size);
    if (source == null) return badge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(height: 4),
        Text(source!, style: AppText.tiny),
      ],
    );
  }
}
