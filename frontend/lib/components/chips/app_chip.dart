import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../emoji/emoji_image.dart';

enum ChipStyle { dark, orange }

/// 분류 · 필터 칩. 선택되면 검정(분류) 또는 주황 테두리(필터).
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.selected = false, this.onTap, this.style = ChipStyle.dark, this.icon, this.trailingArrow = false, this.size = 13});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final ChipStyle style;
  final String? icon;
  final bool trailingArrow; // 품목 ▾ 처럼 고르는 칩
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = !selected
        ? (AppColors.white, AppColors.ink, AppColors.line)
        : style == ChipStyle.dark
        ? (AppColors.ink, AppColors.white, AppColors.ink)
        : (AppColors.orangeBg, AppColors.orange, AppColors.orange);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size + 1, vertical: size * 0.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[EmojiImage(icon!, size: size + 4), const SizedBox(width: 4)],
                if (selected && style == ChipStyle.orange && icon == null) ...[Icon(Icons.check_rounded, size: size + 2, color: fg), const SizedBox(width: 3)],
                Text(
                  label,
                  style: TextStyle(fontSize: size, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: fg),
                ),
                if (trailingArrow) ...[const SizedBox(width: 2), Icon(Icons.arrow_drop_down_rounded, size: size + 7, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 가로로 넘기는 칩 줄
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), children[i]],
      ],
    ),
  );
}
