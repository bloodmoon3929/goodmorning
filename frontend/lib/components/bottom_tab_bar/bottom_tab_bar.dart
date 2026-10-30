import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../emoji/emoji_image.dart';

/// 하단 탭 바: 홈 / 굿즈 탐색 / 매장 찾기 / 마이
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const tabs = [('house', '홈'), ('teddy', '굿즈 탐색'), ('pin', '매장 찾기'), ('smile', '마이')];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == currentIndex,
                  button: true,
                  label: tabs[i].$2,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: i == currentIndex ? 1.08 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: EmojiImage(tabs[i].$1, size: 26),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w500,
                            color: i == currentIndex ? AppColors.orange : AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
