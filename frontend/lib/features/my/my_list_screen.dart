import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/product_card/product_card.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../store/widgets/store_list_card.dart';
import 'my_view_model.dart';
import 'visit_history_screen.dart';

/// 마이의 목록 화면들 (/my/list/:kind)
enum MyListKind {
  favorites('찜한 굿즈'),
  alerts('알림 설정'),
  saved('저장한 매장'),
  purchases('구매 기록'),
  reports('내 제보'),
  inquiries('문의 내역');

  const MyListKind(this.title);
  final String title;
}

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key, required this.kind});

  final MyListKind kind;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(kind.title)),
    body: switch (kind) {
      MyListKind.favorites => const _Favorites(),
      MyListKind.alerts => const _Alerts(),
      MyListKind.saved => const _SavedStores(),
      MyListKind.purchases => const _Purchases(),
      MyListKind.reports => const _Records(reports: true),
      MyListKind.inquiries => const _Records(reports: false),
    },
  );
}

/// 상품 id 목록을 받아 와서 그리는 목록의 바탕
abstract class _ProductListState<T extends StatefulWidget> extends State<T> {
  late final vm = ProductLookupViewModel(AppScope.read(context), ids(AppScope.read(context)));

  List<String> ids(AppState state);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }
}

class _Favorites extends StatefulWidget {
  const _Favorites();

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends _ProductListState<_Favorites> {
  @override
  List<String> ids(AppState state) => state.favorites.toList();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => LoadView<Map<String, ProductSummary>>(
      load: vm.products,
      onRetry: vm.reload,
      skeleton: const SkeletonRows(count: 5),
      builder: (products) {
        if (products.isEmpty) return const _Empty('찜한 굿즈가 없어요', '상품의 ♡를 누르면 여기에 모여요');
        // 찜을 풀어도 화면을 나갈 때까지는 목록에 남겨 둔다 (실수로 눌렀을 때 다시 찜할 수 있게)
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            for (final p in products.values)
              Row(
                children: [
                  Expanded(
                    child: ProductRow(item: p, onTap: () => context.push('/product/${p.product.id}')),
                  ),
                  FavoriteButton(productId: p.product.id),
                  const SizedBox(width: 6),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _Alerts extends StatefulWidget {
  const _Alerts();

  @override
  State<_Alerts> createState() => _AlertsState();
}

class _AlertsState extends _ProductListState<_Alerts> {
  // 알림 종류별 켜고 끄기 (프로토타입: 화면 안에서만 기억)
  final Map<String, bool> _types = {'가격 하락': true, '재입고': true, '저장한 매장 입고': true, '내 IP 새 굿즈': true, '제보 · 문의 답변': true};

  @override
  List<String> ids(AppState state) => state.priceAlerts.toList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _Header('알림 종류'),
          for (final e in _types.entries)
            SwitchListTile(
              title: Text(e.key, style: AppText.body),
              value: e.value,
              activeTrackColor: AppColors.orange,
              onChanged: (v) => setState(() => _types[e.key] = v),
            ),
          const _Header('가격 · 재입고 알림을 받는 굿즈'),
          LoadView<Map<String, ProductSummary>>(
            load: vm.products,
            onRetry: vm.reload,
            skeleton: const SkeletonRows(count: 3, thumb: 48),
            builder: (products) => Column(
              children: [
                if (products.isEmpty) const _Empty('알림을 켠 굿즈가 없어요', '상품 상세의 [알림 받기]를 누르면 여기에 모여요'),
                for (final p in products.values)
                  ListTile(
                    leading: GoodsThumb(emoji: p.product.emoji, bg: p.product.bg, size: 44, radius: 10),
                    title: Text(p.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                    subtitle: Text(p.meta, style: AppText.tiny),
                    trailing: Switch(
                      value: state.priceAlerts.contains(p.product.id),
                      activeTrackColor: AppColors.orange,
                      onChanged: (_) => state.togglePriceAlert(p.product.id),
                    ),
                    onTap: () => context.push('/product/${p.product.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedStores extends StatefulWidget {
  const _SavedStores();

  @override
  State<_SavedStores> createState() => _SavedStoresState();
}

class _SavedStoresState extends State<_SavedStores> {
  late final vm = SavedStoresViewModel(AppScope.read(context));

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = AppScope.of(context).savedStores;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => LoadView<List<StoreSummary>>(
        load: vm.stores,
        onRetry: vm.reload,
        skeleton: const SkeletonCards(count: 2, height: 126, horizontal: false),
        builder: (all) {
          final list = all.where((s) => saved.contains(s.store.id)).toList();
          if (list.isEmpty) return const _Empty('저장한 매장이 없어요', '매장의 [저장]을 누르면 입고 알림을 받을 수 있어요');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => StoreListCard(item: list[i], onTap: () => context.go('/stores/${list[i].store.id}')),
          );
        },
      ),
    );
  }
}

class _Purchases extends StatefulWidget {
  const _Purchases();

  @override
  State<_Purchases> createState() => _PurchasesState();
}

class _PurchasesState extends _ProductListState<_Purchases> {
  // 매장에서 산 기록 (프로토타입 예시 1건)
  static const _storeBuy = ('10/18 · 피규어샵 용산점 · 매장 구매', 'hg-zaku', '단품', 16000);

  @override
  List<String> ids(AppState state) => [...state.visits.map((v) => v.productId), _storeBuy.$2];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final bought = state.visits.where((v) => v.purchased).toList();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => LoadView<Map<String, ProductSummary>>(
        load: vm.products,
        onRetry: vm.reload,
        skeleton: const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonCards(count: 2, height: 132, horizontal: false)),
        builder: (products) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const InfoBanner('이동 기록에서 [구매했어요]를 누르면 여기에 모여요'),
            const SizedBox(height: 14),
            for (final v in bought)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VisitCard(visit: v, product: products[v.productId]),
              ),
            _storeCard(products[_storeBuy.$2]),
          ],
        ),
      ),
    );
  }

  Widget _storeCard(ProductSummary? p) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_storeBuy.$1, style: AppText.caption),
        const SizedBox(height: 8),
        Row(
          children: [
            if (p != null) GoodsThumb(emoji: p.product.emoji, bg: p.product.bg, size: 44, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p?.product.name ?? ''} · ${_storeBuy.$3}', style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(won(_storeBuy.$4), style: AppText.label),
                ],
              ),
            ),
            const Pill('✓ 구매함', fg: AppColors.green, bg: AppColors.greenBg),
          ],
        ),
      ],
    ),
  );
}

/// 내 제보 · 문의 내역
class _Records extends StatelessWidget {
  const _Records({required this.reports});

  final bool reports;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = reports ? state.reports : state.inquiries;
    if (list.isEmpty) return _Empty(reports ? '보낸 제보가 없어요' : '문의 내역이 없어요', reports ? '매장 상세에서 재고를 제보할 수 있어요' : '이동 기록에서 [문제 제기]를 누를 수 있어요');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _RecordCard(record: list[i]),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final MyRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final (fg, bg) = r.done ? (AppColors.green, AppColors.greenBg) : (AppColors.amber, AppColors.amberBg);
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: r.storeId != null
            ? () => context.go('/stores/${r.storeId}')
            : r.productId != null
            ? () => context.push('/product/${r.productId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.title, style: AppText.bodyStrong)),
                  Pill(r.status, fg: fg, bg: bg),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.body, style: AppText.label),
              const SizedBox(height: 4),
              Text(r.whenLabel, style: AppText.tiny),
              if (r.answer != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                  child: Text('답변 · ${r.answer}', style: AppText.caption.copyWith(color: AppColors.ink)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      text,
      style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.sub);
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.body.copyWith(color: AppColors.sub)),
          const SizedBox(height: 4),
          Text(sub, style: AppText.caption, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
