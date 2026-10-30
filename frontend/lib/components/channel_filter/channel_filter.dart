import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/sales.dart';
import '../emoji/emoji_image.dart';

/// 판매 경로 필터: 전체 / 🌐 온라인 / 📍 오프라인.
/// 앱 전체가 같은 값을 쓴다 (홈에서 고르면 굿즈 탐색 · 검색 결과도 같은 기준).
class ChannelFilter extends StatelessWidget {
  const ChannelFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(19)),
      child: Row(
        children: [
          for (final c in Channel.values)
            Expanded(
              child: Semantics(
                selected: state.channel == c,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => state.setChannel(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: state.channel == c ? AppColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: state.channel == c ? AppColors.line : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c == Channel.online) const EmojiImage('globe', size: 14),
                        if (c == Channel.offline) const EmojiImage('pin', size: 14),
                        if (c != Channel.all) const SizedBox(width: 4),
                        Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: state.channel == c ? FontWeight.w600 : FontWeight.w500,
                            color: state.channel == c ? AppColors.ink : AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
