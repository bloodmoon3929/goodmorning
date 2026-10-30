import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/external_move/external_move.dart';
import '../../components/external_move/login_gate.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/skeleton/skeleton.dart';
import '../../components/stock_badge/stock_badge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sales.dart';
import 'store_view_model.dart';
import 'widgets/stock_report_sheet.dart';

/// 19. 매장 상세 — 매장 카드 · 지도 마커 · 상품 상세의 매장을 누르면 들어오는 화면
class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.storeId});

  final String storeId;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late final vm = StoreDetailViewModel(AppScope.read(context), widget.storeId);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  /// 20. 재고 제보: 아래에서 올라오는 창
  Future<void> _report(StoreDetail d, [StoreStockItem? item]) async {
    if (!await ensureMember(context, '재고 제보')) return;
    if (!mounted) return;
    final sent = await showStockReportSheet(context, detail: d, initial: item, onSend: vm.report);
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d.store.hasOwner ? '제보를 보냈어요. 사장님이 확인하면 반영돼요' : '제보를 보냈어요. 같은 제보가 2건 모이면 반영돼요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final d = vm.detail.valueOrNull;
        return Scaffold(
          appBar: AppBar(title: Text(d?.store.name ?? '')),
          body: LoadView<StoreDetail>(
            load: vm.detail,
            onRetry: vm.reload,
            skeleton: const Column(
              children: [
                SizedBox(height: 8),
                SkeletonRows(count: 1, thumb: 56),
                SkeletonCards(count: 4, height: 70),
                SizedBox(height: 20),
                SkeletonRows(count: 4, thumb: 44),
              ],
            ),
            builder: _body,
          ),
        );
      },
    );
  }

  Widget _body(StoreDetail d) {
    final s = d.store;
    final state = AppScope.of(context);
    final saved = state.savedStores.contains(s.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: const EmojiImage('store', size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.kind, style: AppText.bodyStrong),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      const Pill('영업 중', fg: AppColors.green, bg: AppColors.greenBg),
                      Pill(s.distanceLabel, fg: AppColors.sub, bg: AppColors.bg),
                      if (s.popupEnds != null) Pill(s.popupEnds!, fg: AppColors.red, bg: AppColors.redBg),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final (label, value) in [('주소', s.address), ('영업', s.hours), ('전화', s.phone)])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(label, style: AppText.label.copyWith(color: AppColors.sub)),
                ),
                Expanded(child: Text(value, style: AppText.label)),
              ],
            ),
          ),
        Text(s.infoSource, style: AppText.tiny),
        const SizedBox(height: 14),
        Row(
          children: [
            _ActionTile('compass', '길찾기', () => showExternalMove(context, kind: ExternalKind.map, target: s.name)),
            _ActionTile('phone', '전화', () => showExternalMove(context, kind: ExternalKind.phone, target: s.name, detail: s.phone)),
            _ActionTile('star', saved ? '저장됨' : '저장', () => state.toggleSavedStore(s.id), on: saved),
            _ActionTile('link', '공유', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('매장 링크를 복사했어요')))),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Text('재고', style: AppText.section)),
            TextButton(
              onPressed: () => _report(d),
              child: Text(
                '재고가 다른가요? 제보하기 ›',
                style: AppText.label.copyWith(color: AppColors.orange, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (d.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('등록된 재고가 없어요', style: AppText.caption)),
          ),
        for (final item in d.items) _stockRow(d, item),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정 제안은 다음 단계에서 열려요'))),
            child: Text('매장 정보가 달라요? 수정 제안 ›', style: AppText.caption),
          ),
        ),
      ],
    );
  }

  Widget _stockRow(StoreDetail d, StoreStockItem item) {
    final p = item.product;
    final mine = vm.myReports['${p.id}/${item.variant.id}'];
    return InkWell(
      onTap: () => context.push('/product/${p.id}?v=${item.variant.id}&tab=offline'),
      onLongPress: () => _report(d, item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            GoodsThumb(emoji: p.emoji, bg: p.bg, size: 44, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text('${item.variant.label} · ${item.stock.sourceLabel}', style: AppText.tiny),
                  if (mine != null) ...[
                    const SizedBox(height: 2),
                    Text('내 제보: ${mine.$1.short} · ${mine.$2}', style: AppText.tiny.copyWith(color: AppColors.orange)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StockBadge(item.stock.status),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.emoji, this.label, this.onTap, {this.on = false});

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: on ? AppColors.orangeBg : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmojiImage(emoji, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: on ? AppColors.orange : AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
