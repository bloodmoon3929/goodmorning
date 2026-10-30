import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/chips/app_chip.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import 'notification_view_model.dart';

/// 9. 알림 목록 — 홈의 🔔 에서 들어오는 화면
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final vm = NotificationViewModel(AppScope.read(context));

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  void _open(NotificationItem n) {
    final state = AppScope.read(context);
    state.markRead(n.id);
    if (n.type == NotificationType.inquiry || n.type == NotificationType.report) {
      context.go('/my/list/${n.type == NotificationType.inquiry ? 'inquiries' : 'reports'}');
    } else if (n.storeId != null && n.type == NotificationType.arrival) {
      context.go('/stores/${n.storeId}');
    } else if (n.productId != null) {
      context.push('/product/${n.productId}');
    } else if (n.ipId != null) {
      context.go('/explore/ip/${n.ipId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [TextButton(onPressed: state.unreadCount > 0 ? state.markAllRead : null, child: const Text('모두 읽음'))],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            const SizedBox(height: 4),
            ChipRow(
              children: [for (final f in NotificationViewModel.filters) AppChip(f, selected: vm.filter == f, onTap: () => vm.setFilter(f))],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LoadView<List<NotificationItem>>(
                load: vm.items,
                onRetry: vm.reload,
                skeleton: const SkeletonRows(count: 6, thumb: 44),
                builder: (all) {
                  final list = vm.visible(all);
                  final today = list.where((n) => !n.thisWeek).toList();
                  final week = list.where((n) => n.thisWeek).toList();
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Text('알림이 없어요', style: AppText.caption)),
                        ),
                      if (today.isNotEmpty) _group('오늘', today, state),
                      if (week.isNotEmpty) _group('이번 주', week, state),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/my/list/alerts'),
                          child: Text('알림 설정 ›', style: AppText.label.copyWith(color: AppColors.sub)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, List<NotificationItem> items, AppState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          title,
          style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
        ),
      ),
      for (final n in items) _tile(n, !state.readNotifications.contains(n.id)),
    ],
  );

  Widget _tile(NotificationItem n, bool unread) {
    return Material(
      color: unread ? AppColors.unreadBg : AppColors.white,
      child: InkWell(
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 10,
                child: unread
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: EmojiImage(n.type.emoji, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: unread ? AppText.bodyStrong : AppText.body.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(n.body, style: AppText.caption),
                    const SizedBox(height: 2),
                    Text(n.timeLabel, style: AppText.tiny),
                  ],
                ),
              ),
              // 굿즈 알림은 사진을 함께 보여 준다
              if (n.thumbEmoji != null) ...[const SizedBox(width: 8), GoodsThumb(emoji: n.thumbEmoji!, bg: n.thumbBg!, size: 52, radius: 10)],
            ],
          ),
        ),
      ),
    );
  }
}
