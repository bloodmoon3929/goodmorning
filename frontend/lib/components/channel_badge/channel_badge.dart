import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../emoji/emoji_image.dart';

/// 알약 모양 배지. 아이콘(이모지) + 글자.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.fg, required this.bg, this.icon, this.size = 11, this.border});

  final String label;
  final Color fg;
  final Color bg;
  final String? icon;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * 0.72, vertical: size * 0.28),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[EmojiImage(icon!, size: size + 3), const SizedBox(width: 3)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: fg, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

/// 🌐 온라인 배지: 판매 몰 수 · 배송비 포함 최저 총액
class OnlineBadge extends StatelessWidget {
  const OnlineBadge(this.label, {super.key, this.size = 11});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Pill(label, fg: AppColors.blue, bg: AppColors.blueBg, icon: 'globe', size: size);
}

/// 📍 오프라인 배지: 근처 재고 있는 매장 수
class OfflineBadge extends StatelessWidget {
  const OfflineBadge(this.label, {super.key, this.size = 11});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Pill(label, fg: AppColors.green, bg: AppColors.greenBg, icon: 'pin', size: size);
}

/// 상품 카드 · 결과 행의 배지 두 개. 판매 경로가 없는 쪽 배지는 숨긴다.
/// 판매 경로 필터가 온라인이면 온라인 배지만, 오프라인이면 오프라인 배지만 보인다.
class ChannelBadges extends StatelessWidget {
  const ChannelBadges(this.channels, {super.key, this.compact = false, this.axis = Axis.vertical, this.size = 11});

  final ChannelSummary channels;
  final bool compact; // 9,900원~ / 근처 2곳 처럼 짧게
  final Axis axis;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filter = AppScope.of(context).channel;
    final showOn = channels.hasOnline && filter != Channel.offline;
    final showOff = channels.hasOffline && filter != Channel.online;
    final on = compact ? '${won(channels.minTotal ?? 0)}~' : '${channels.onlineMalls}곳 · ${won(channels.minTotal ?? 0)}~';
    final off = compact ? '근처 ${channels.nearbyStores}곳' : '근처 ${channels.nearbyStores}곳 재고';
    final children = [if (showOn) OnlineBadge(on, size: size), if (showOff) OfflineBadge(off, size: size)];
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(direction: axis, spacing: 6, runSpacing: 5, children: children);
  }
}
