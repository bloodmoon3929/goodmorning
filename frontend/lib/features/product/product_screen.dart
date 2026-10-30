import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/chips/app_chip.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/external_move/external_move.dart';
import '../../components/external_move/login_gate.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/product_card/product_card.dart';
import '../../components/skeleton/skeleton.dart';
import '../../components/stock_badge/stock_badge.dart';
import '../../components/store_card/store_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sales.dart';
import 'product_view_model.dart';
import 'widgets/mall_price_row.dart';

export 'product_view_model.dart' show ProductTab;

/// 15. 상품 상세 · 온라인 가격 / 16. 오프라인 매장 / 비슷한 굿즈 — 어느 화면에서든 상품을 누르면 들어오는 화면
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.productId, this.variantId, this.initialTab = ProductTab.online});

  final String productId;
  final String? variantId;
  final ProductTab initialTab;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final vm = ProductViewModel(AppScope.read(context), widget.productId, variantId: widget.variantId, tab: widget.initialTab);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  /// 구매하러 가기: 외부 몰로 이동 (이동 기록에 당시 가격 저장)
  Future<void> _buy(ProductDetail d, MallOffer o) async {
    final state = AppScope.read(context);
    if (state.isMember) {
      state.recordVisit(productId: d.product.id, variantLabel: vm.variant(d).label, offer: o);
      await showExternalMove(context, kind: ExternalKind.mall, target: o.mall, detail: '구매하러 가기를 누른 시점의 가격 ${won(o.total)}을(를) 이동 기록에 저장했어요');
    } else {
      await showExternalMove(context, kind: ExternalKind.mall, target: o.mall, detail: '로그인하면 이동 기록에 당시 가격이 저장돼요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final d = vm.detail.valueOrNull;
        return Scaffold(
          appBar: AppBar(
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상품 링크를 복사했어요'))),
                child: Text('공유', style: AppText.label),
              ),
              FavoriteButton(productId: widget.productId, color: AppColors.ink),
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: d == null ? null : _bottomBar(d),
          body: LoadView<ProductDetail>(
            load: vm.detail,
            onRetry: vm.reload,
            skeleton: const Shimmer(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 136, radius: 16),
                    SizedBox(height: 14),
                    SkeletonBox(width: 90, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 20),
                    SizedBox(height: 16),
                    SkeletonBox(height: 62, radius: 12),
                    SizedBox(height: 20),
                    SkeletonBox(height: 44),
                    SizedBox(height: 12),
                    SkeletonBox(height: 44),
                  ],
                ),
              ),
            ),
            builder: (d) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _header(d),
                _tabs(),
                ...switch (vm.tab) {
                  ProductTab.online => _online(d),
                  ProductTab.offline => _offline(d),
                  ProductTab.similar => _similar(d),
                },
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(ProductDetail d) {
    final p = d.product;
    final v = vm.variant(d);
    final best = vm.best(d);
    final chars = d.characters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'product-${p.id}',
            child: GoodsThumb(emoji: p.emoji, bg: p.bg, width: double.infinity, height: 136, radius: 16, emojiScale: 0.62),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: chars.isEmpty ? null : () => context.go('/explore/ip/${p.ipId}/character/${chars.first.id}'),
            child: Text(
              '${d.ipName} › ${chars.map((c) => c.name).join(', ')}',
              style: AppText.caption.copyWith(color: AppColors.blue, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          Text(p.name, style: AppText.title.copyWith(fontSize: 19)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('버전', style: AppText.caption),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [for (final x in p.variants) AppChip(x.label, size: 12, selected: x.id == v.id, onTap: () => vm.selectVariant(x.id))],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryBox(
                  icon: 'globe',
                  label: '온라인 ${vm.onlineMalls(d)}곳',
                  value: best == null ? '판매처 없음' : '최저 ${won(best.total)}',
                  fg: AppColors.blue,
                  bg: AppColors.blueBg,
                  onTap: () => vm.setTab(ProductTab.online),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryBox(
                  icon: 'pin',
                  label: '오프라인',
                  value: vm.nearbyInStock(d) == 0 ? '근처 재고 없음' : '근처 ${vm.nearbyInStock(d)}곳 재고',
                  fg: AppColors.green,
                  bg: AppColors.greenBg,
                  onTap: () => vm.setTab(ProductTab.offline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryBox({required String icon, required String label, required String value, required Color fg, required Color bg, required VoidCallback onTap}) =>
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EmojiImage(icon, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: AppText.section.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      );

  Widget _tabs() => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final t in ProductTab.values)
          Expanded(
            child: InkWell(
              onTap: () => vm.setTab(t),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Text(
                      t.label,
                      style: t == vm.tab ? AppText.bodyStrong.copyWith(fontWeight: FontWeight.w700) : AppText.body.copyWith(color: AppColors.sub),
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: t == vm.tab ? AppColors.orange : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  List<Widget> _online(ProductDetail d) {
    final offers = vm.offers(d);
    final best = vm.best(d);
    if (offers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('온라인 판매처가 아직 없어요', style: AppText.caption)),
        ),
      ];
    }
    return [
      for (final o in offers) ...[MallPriceRow(offer: o, isBest: identical(o, best), onBuy: () => _buy(d, o)), const Divider(indent: 16, endIndent: 16)],
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(child: Text('배송비 포함 총액 순 · 가격은 몰에서 바뀔 수 있어요', style: AppText.tiny)),
      ),
    ];
  }

  List<Widget> _offline(ProductDetail d) {
    final stocks = vm.stocks(d);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            const AppChip('가까운 순', size: 12),
            const SizedBox(width: 8),
            AppChip('재고 있는 곳만', size: 12, selected: vm.inStockOnly, style: ChipStyle.orange, onTap: vm.toggleInStock),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/stores?view=map'),
              child: Text('지도 ›', style: AppText.label.copyWith(color: AppColors.blue)),
            ),
          ],
        ),
      ),
      if (stocks.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('근처 매장 재고 정보가 없어요', style: AppText.caption)),
        ),
      for (final s in stocks) ...[
        InkWell(
          onTap: () => context.go('/stores/${s.storeId}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.stores[s.storeId]!.name,
                            style: AppText.bodyStrong.copyWith(color: s.status == StockStatus.check ? AppColors.sub : AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(d.stores[s.storeId]!.openLabel, style: AppText.tiny),
                        ],
                      ),
                    ),
                    StockBadge(s.status, source: s.sourceLabel),
                  ],
                ),
                const SizedBox(height: 10),
                StoreActions(store: d.stores[s.storeId]!, showSave: false, height: 30),
              ],
            ),
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(child: Text('확인한 지 48시간이 지나면 "확인 필요"로 보여요', style: AppText.tiny)),
      ),
    ];
  }

  List<Widget> _similar(ProductDetail d) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Text('사진 · 이름이 비슷한 굿즈 (EmbeddingGemma 2)', style: AppText.caption),
    ),
    GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 18, mainAxisExtent: 238),
      itemCount: d.similar.length,
      itemBuilder: (_, i) => ProductCard(item: d.similar[i], onTap: () => context.push('/product/${d.similar[i].product.id}')),
    ),
  ];

  Widget _bottomBar(ProductDetail d) {
    final state = AppScope.of(context);
    final alert = state.priceAlerts.contains(d.product.id);
    final best = vm.best(d);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: FavoriteButton(productId: d.product.id, color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              AppButton(
                alert ? '알림 켜짐' : '알림 받기',
                kind: alert ? AppButtonKind.soft : AppButtonKind.secondary,
                icon: 'bell',
                expand: false,
                height: 48,
                fontSize: 13,
                onPressed: () async {
                  if (!await ensureMember(context, '가격 하락 · 재입고 알림')) return;
                  state.togglePriceAlert(d.product.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(alert ? '알림을 껐어요' : '가격이 내려가거나 다시 들어오면 알려 드려요')));
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: vm.tab == ProductTab.offline
                    ? AppButton('지도에서 매장 보기', height: 48, fontSize: 15, onPressed: () => context.go('/stores?view=map'))
                    : AppButton('최저가로 구매하러 가기', height: 48, fontSize: 15, onPressed: best == null ? null : () => _buy(d, best)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
