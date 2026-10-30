import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/bottom_sheet/app_bottom_sheet.dart';
import '../../components/buttons/app_button.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/external_move/login_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sales.dart';
import 'my_list_screen.dart';

/// 21. 마이 — 하단 탭 [마이]
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  Future<void> _settings(BuildContext context) => showAppBottomSheet<void>(
    context,
    title: '설정',
    builder: (ctx) {
      final state = AppScope.of(ctx);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('판매 경로 기본값', style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Text('홈 · 검색 · 상품 목록의 배지를 이 경로만 보여 줘요', style: AppText.caption),
          const SizedBox(height: 10),
          SegmentedButton<Channel>(
            showSelectedIcon: false,
            segments: [for (final c in Channel.values) ButtonSegment(value: c, label: Text(c.label))],
            selected: {state.channel},
            onSelectionChanged: (s) => state.setChannel(s.first),
          ),
          const SizedBox(height: 22),
          AppButton(
            state.isMember ? '로그아웃' : '로그인하기',
            kind: AppButtonKind.secondary,
            height: 48,
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
              context.go('/login');
            },
          ),
        ],
      );
    },
  );

  Future<void> _open(BuildContext context, String location, {String? action}) async {
    if (action != null && !await ensureMember(context, action)) return;
    if (context.mounted) context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('마이', style: AppText.display)),
                  TextButton.icon(
                    onPressed: () => _settings(context),
                    icon: const EmojiImage('gear', size: 20),
                    label: Text('설정', style: AppText.body.copyWith(fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: state.isMember ? _profile(context, state) : _guest(context, state)),
            const SizedBox(height: 12),
            _group('내 굿즈', [
              _Row('red_heart', MyListKind.favorites.title, '${state.favorites.length}', () => _open(context, '/my/list/favorites', action: '찜')),
              _Row('bell', MyListKind.alerts.title, '${state.priceAlerts.length}개 켜짐', () => _open(context, '/my/list/alerts', action: '알림')),
              _Row('star', MyListKind.saved.title, '${state.savedStores.length}', () => _open(context, '/my/list/saved')),
            ]),
            _group('내 기록', [
              _Row('cart', '이동 기록', '${state.visits.length}', () => _open(context, '/my/history', action: '이동 기록')),
              _Row('receipt', MyListKind.purchases.title, '${state.purchasedCount}', () => _open(context, '/my/list/purchases', action: '구매 기록')),
              _Row('memo', MyListKind.reports.title, '${state.reports.length}', () => _open(context, '/my/list/reports', action: '제보')),
              _Row('speech', MyListKind.inquiries.title, '${state.inquiries.length}', () => _open(context, '/my/list/inquiries', action: '문의')),
            ]),
            if (state.isSeller && state.isMember)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Material(
                  color: AppColors.orangeBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/seller'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const EmojiImage('store', size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '사장님이신가요?',
                                  style: AppText.bodyStrong.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text('판매자 센터에서 매장 재고를 관리하세요 ›', style: AppText.caption.copyWith(color: AppColors.ink)),
                              ],
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
      ),
    );
  }

  Widget _profile(BuildContext context, AppState state) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const EmojiImage('smile', size: 36),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.profile.nickname, style: AppText.title),
              const SizedBox(height: 2),
              Text('${state.profile.email} · ${state.profile.region}', style: AppText.caption),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.push('/ip-manage'),
                child: Pill('내 IP ${state.myIps.length}개 · 바꾸기 ›', fg: AppColors.orange, bg: AppColors.orangeBg, size: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _guest(BuildContext context, AppState state) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('둘러보는 중이에요', style: AppText.title),
        const SizedBox(height: 4),
        Text('로그인하면 찜 · 알림 · 제보 · 이동 기록이 계정에 저장돼요', style: AppText.caption),
        const SizedBox(height: 12),
        AppButton(
          '로그인 · 회원가입',
          height: 44,
          fontSize: 14,
          onPressed: () {
            state.logout();
            context.go('/login');
          },
        ),
      ],
    ),
  );

  Widget _group(String title, List<_Row> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            title,
            style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
          ),
        ),
        ...rows,
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.emoji, this.label, this.value, this.onTap);

  final String emoji;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          EmojiImage(emoji, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Text('$value ›', style: AppText.body.copyWith(color: AppColors.sub)),
        ],
      ),
    ),
  );
}
