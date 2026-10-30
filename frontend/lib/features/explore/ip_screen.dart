import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_filter/channel_filter.dart';
import '../../components/chips/app_chip.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/product_card/product_card.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search.dart';
import 'explore_view_model.dart';

/// 13. IP 화면 — 굿즈 탐색에서 IP를 고르면 보이는 화면 (예: 산리오)
class IpScreen extends StatefulWidget {
  const IpScreen({super.key, required this.ipId});

  final String ipId;

  @override
  State<IpScreen> createState() => _IpScreenState();
}

class _IpScreenState extends State<IpScreen> {
  late final vm = IpViewModel(AppScope.read(context), widget.ipId);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> _sort() async {
    final s = await showModalBottomSheet<SearchSort>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in [SearchSort.popular, SearchSort.lowest, SearchSort.newest])
              ListTile(
                title: Text(s.label),
                trailing: s == vm.sort ? const Icon(Icons.check_rounded, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (s != null) vm.setSort(s);
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(vm.detail.valueOrNull?.ip.name ?? '')),
        body: LoadView<IpDetail>(
          load: vm.detail,
          onRetry: vm.reload,
          skeleton: const Column(children: [SizedBox(height: 60), SkeletonTiles(circle: true), SizedBox(height: 24), SkeletonProductGrid(rows: 2)]),
          builder: (d) {
            final list = vm.visible(d);
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 14), child: ChannelFilter()),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 94,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        _character('전체', d.ip.emoji, d.ip.bg, selected: true, onTap: () {}),
                        for (final c in d.characters) _character(c.name, c.emoji, c.bg, onTap: () => context.push('/explore/ip/${d.ip.id}/character/${c.id}')),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ChipRow(
                    children: [
                      AppChip('전체', size: 12, selected: vm.category == null, onTap: () => vm.setCategory(null)),
                      for (final c in vm.categories(d)) AppChip(c.label, size: 12, selected: vm.category == c, onTap: () => vm.setCategory(c)),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
                    child: Row(
                      children: [
                        Text(
                          '굿즈 ${list.length}개',
                          style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _sort,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          label: Text(vm.sort.label, style: AppText.label),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 18,
                      mainAxisExtent: 238,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => ProductCard(item: list[i], onTap: () => context.push('/product/${list[i].product.id}')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _character(String name, String emoji, Color bg, {bool selected = false, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppColors.orange : Colors.transparent, width: 2),
            ),
            child: GoodsThumb(emoji: emoji, bg: bg, size: 54, circle: true, emojiScale: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              fontSize: 12,
              color: selected ? AppColors.orange : AppColors.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
