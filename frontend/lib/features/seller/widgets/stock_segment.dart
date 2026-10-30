import 'package:flutter/material.dart';

import '../../../components/stock_badge/stock_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/sales.dart';

/// 재고 많음 · 적음 · 없음 세 칸 고르기 (판매자 센터)
class StockSegment extends StatelessWidget {
  const StockSegment({super.key, required this.value, required this.onChanged, this.width = 150, this.height = 30});

  final StockStatus value;
  final ValueChanged<StockStatus> onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(height / 2)),
    child: Row(
      children: [
        for (final s in const [StockStatus.many, StockStatus.few, StockStatus.none]) Expanded(child: _cell(s)),
      ],
    ),
  );

  Widget _cell(StockStatus s) {
    final on = s == value;
    final (fg, bg) = stockColors(s);
    return Semantics(
      selected: on,
      button: true,
      label: s.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: on
              ? BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(color: fg),
                )
              : const BoxDecoration(color: Colors.transparent),
          child: Text(
            s.short,
            style: TextStyle(fontSize: height > 32 ? 13 : 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? fg : AppColors.sub),
          ),
        ),
      ),
    );
  }
}
