import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_filter/channel_filter.dart';
import '../../components/chips/app_chip.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/product_card/product_card.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/network/load_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../models/search.dart';
import 'search_view_model.dart';

/// 10. 검색 결과 — 검색창에 입력한 뒤 보이는 화면. 굿즈 탐색의 품목으로 보기도 이 화면을 쓴다.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = '', this.category, this.sort = SearchSort.lowest});

  final String initialQuery;
  final GoodsCategory? category;
  final SearchSort sort;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final vm = SearchViewModel(AppScope.read(context), text: widget.initialQuery, category: widget.category, sort: widget.sort);
  late final _text = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isEmpty && widget.category == null && widget.sort == SearchSort.lowest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    vm.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setText(String t) {
    _text.text = t;
    _text.selection = TextSelection.collapsed(offset: t.length);
    vm.submit(t);
  }

  Future<void> _pick<T>(String title, List<T> options, String Function(T) label, T current, ValueChanged<T> onPick) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppText.title),
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(label(o), style: AppText.body),
                trailing: o == current ? const Icon(Icons.check_rounded, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // 판매 경로 필터가 바뀌면 다시 그린다
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: vm.typed,
            onSubmitted: vm.submit,
            style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '굿즈 이름, 캐릭터 검색',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)), borderSide: BorderSide.none),
              enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)), borderSide: BorderSide.none),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)), borderSide: BorderSide.none),
              suffixIcon: ListenableBuilder(
                listenable: _text,
                builder: (_, _) => _text.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(tooltip: '지우기', icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => _setText('')),
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final r = vm.result;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(r?.valueOrNull)),
              if (r == null) SliverToBoxAdapter(child: _suggestions()) else ..._results(r),
            ],
          );
        },
      ),
    );
  }

  Widget _header(SearchResult? r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (r?.alias != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '‘${r!.alias!.$1}’를 ‘${r.alias!.$2}’로 함께 찾았어요',
            style: AppText.label.copyWith(color: AppColors.orange, fontWeight: FontWeight.w600),
          ),
        ),
      const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 10), child: ChannelFilter()),
      ChipRow(
        children: [
          AppChip(
            vm.query.category?.label ?? '품목',
            selected: vm.query.category != null,
            trailingArrow: true,
            size: 12,
            onTap: () => _pick<GoodsCategory?>('품목', [null, ...GoodsCategory.values], (c) => c?.label ?? '전체', vm.query.category, vm.setCategory),
          ),
          AppChip(
            vm.query.price == PriceRange.any ? '가격' : vm.query.price.label,
            selected: vm.query.price != PriceRange.any,
            trailingArrow: true,
            size: 12,
            onTap: () => _pick<PriceRange>('가격', PriceRange.values, (p) => p.label, vm.query.price, vm.setPrice),
          ),
          AppChip(
            vm.query.sort.label,
            trailingArrow: true,
            size: 12,
            onTap: () => _pick<SearchSort>('정렬', SearchSort.values, (s) => s.label, vm.query.sort, vm.setSort),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ],
  );

  Widget _suggestions() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('최근 검색어', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in SearchViewModel.recent) AppChip(t, size: 12, onTap: () => _setText(t))]),
        const SizedBox(height: 22),
        const Text('많이 찾는 굿즈', style: AppText.bodyStrong),
        const SizedBox(height: 6),
        for (final (i, t) in SearchViewModel.popular.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Text('${i + 1}', style: AppText.bodyStrong.copyWith(color: AppColors.orange)),
            title: Text(t, style: AppText.body),
            onTap: () => _setText(t),
          ),
        const SizedBox(height: 12),
        Text('별칭으로도 찾아요: 먼작귀 → 치이카와, 건프라 → 건담', style: AppText.caption),
      ],
    ),
  );

  List<Widget> _results(Load<SearchResult> r) {
    return switch (r) {
      Loaded<SearchResult>(:final value) => () {
        final list = vm.filtered(value.items);
        return <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '검색 결과 ${list.length}개',
                style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (value.ips.isNotEmpty && vm.query.text.isNotEmpty)
            SliverToBoxAdapter(
              child: ChipRow(
                children: [
                  for (final ip in value.ips) AppChip('${ip.name} IP 화면 ›', icon: ip.emoji, size: 12, onTap: () => context.go('/explore/ip/${ip.id}')),
                ],
              ),
            ),
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const EmojiImage('magnifier', size: 56),
                    const SizedBox(height: 10),
                    Text('찾는 굿즈가 없어요.\n다른 이름이나 판매 경로로 찾아보세요', textAlign: TextAlign.center, style: AppText.caption),
                  ],
                ),
              ),
            ),
          SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
            itemBuilder: (_, i) => ProductRow(item: list[i], onTap: () => context.push('/product/${list[i].product.id}')),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ];
      }(),
      LoadFailed<SearchResult>() => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TextButton(onPressed: vm.run, child: const Text('다시 시도')),
          ),
        ),
      ],
      Loading<SearchResult>() => [const SliverToBoxAdapter(child: SkeletonRows(count: 5))],
    };
  }
}
