import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/bottom_sheet/app_bottom_sheet.dart';
import '../../components/buttons/app_button.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/chips/app_chip.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/skeleton/skeleton.dart';
import '../../components/store_card/store_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sales.dart';
import 'store_view_model.dart';
import 'widgets/fake_map.dart';
import 'widgets/store_list_card.dart';

/// 17. 매장 찾기 · 리스트 / 18. 지도 — 하단 탭 [매장 찾기]
class StoreFinderScreen extends StatefulWidget {
  const StoreFinderScreen({super.key, this.initialMap = false});

  final bool initialMap;

  @override
  State<StoreFinderScreen> createState() => _StoreFinderScreenState();
}

class _StoreFinderScreenState extends State<StoreFinderScreen> {
  late final vm = StoreFinderViewModel(AppScope.read(context), map: widget.initialMap);
  late List<String> _ips = AppScope.read(context).myIps;

  @override
  void didUpdateWidget(StoreFinderScreen old) {
    super.didUpdateWidget(old);
    // 홈의 [지도 보기]로 다시 들어오면 지도로
    if (widget.initialMap != old.initialMap) vm.setMap(widget.initialMap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 내 IP가 바뀌면 매장별 "내 IP 굿즈 재고 수"를 다시 센다
    final ips = AppScope.of(context).myIps;
    if (ips.join(',') != _ips.join(',')) {
      _ips = ips;
      vm.reload();
    }
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> _changeRegion() async {
    const regions = ['용산구 한강로', '마포구 서교동', '성동구 성수동', '광진구 화양동'];
    final r = await showAppBottomSheet<String>(
      context,
      title: '위치 바꾸기',
      builder: (ctx) => Column(
        children: [
          for (final r in regions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const EmojiImage('pin', size: 22),
              title: Text(r, style: AppText.body),
              trailing: r == vm.region ? const Icon(Icons.check_rounded, color: AppColors.orange) : null,
              onTap: () => Navigator.pop(ctx, r),
            ),
        ],
      ),
    );
    if (r != null) vm.setRegion(r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _top(),
              Expanded(
                child: LoadView<List<StoreSummary>>(
                  load: vm.stores,
                  onRetry: vm.reload,
                  skeleton: vm.showMap
                      ? const Shimmer(child: SkeletonBox(height: 600, radius: 0))
                      : const SkeletonCards(count: 4, height: 126, horizontal: false),
                  builder: (all) {
                    final list = vm.visible(all);
                    return vm.showMap ? _map(list) : _list(list);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _top() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Row(
          children: [
            const Expanded(child: Text('매장 찾기', style: AppText.display)),
            _Segment(map: vm.showMap, onChanged: vm.setMap),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          onChanged: vm.setQuery,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '매장 이름 · 지역 검색',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.sub),
            isDense: true,
          ),
        ),
      ),
      const SizedBox(height: 10),
      ChipRow(
        children: [
          AppChip('재고 있는 곳만', selected: vm.inStockOnly, style: ChipStyle.orange, size: 12, onTap: vm.toggleInStock),
          AppChip('팝업 포함', selected: vm.includePopup, style: ChipStyle.orange, size: 12, onTap: vm.togglePopup),
          AppChip('굿즈: 내 IP', size: 12, trailingArrow: true, onTap: () => context.push('/ip-manage')),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 4),
        child: Row(
          children: [
            const EmojiImage('pin', size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text('현재 위치 · ${vm.region}', style: AppText.label)),
            TextButton(
              onPressed: _changeRegion,
              child: Text(
                '변경',
                style: AppText.label.copyWith(color: AppColors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _list(List<StoreSummary> list) {
    if (list.isEmpty) return const _Empty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => StoreListCard(item: list[i], onTap: () => context.go('/stores/${list[i].store.id}')),
    );
  }

  Widget _map(List<StoreSummary> list) {
    final selected = list.where((s) => s.store.id == vm.selectedId).firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: FakeMap(stores: list, selectedId: vm.selectedId, onSelect: vm.select),
        ),
        const Positioned(left: 16, top: 12, child: MapLegend()),
        if (list.isEmpty) const Positioned(left: 0, right: 0, top: 80, child: _Empty()),
        // 마커를 누르면 아래 카드로 매장 미리보기
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _MapPreview(item: selected, onDetail: () => context.go('/stores/${selected.store.id}')),
          )
        else if (list.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(18)),
                child: Text('마커를 누르면 매장 정보를 볼 수 있어요', style: AppText.caption.copyWith(color: AppColors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.map, required this.onChanged});

  final bool map;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(18)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, label) in [(false, '리스트'), (true, '지도')])
          Semantics(
            selected: v == map,
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 62,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == map ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  border: v == map ? Border.all(color: AppColors.line) : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: v == map ? FontWeight.w600 : FontWeight.w500, color: v == map ? AppColors.ink : AppColors.sub),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.item, required this.onDetail});

  final StoreSummary item;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final s = item.store;
    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(s.name, style: AppText.section)),
                if (s.popupEnds != null) Pill(s.popupEnds!, fg: AppColors.red, bg: AppColors.redBg, size: 10),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.openLabel, style: AppText.caption),
            const SizedBox(height: 8),
            item.myIpStock > 0
                ? Pill('내 IP 굿즈 재고 ${item.myIpStock}개', fg: AppColors.green, bg: AppColors.greenBg)
                : const Pill('재고 확인 필요', fg: AppColors.sub, bg: AppColors.bg),
            const SizedBox(height: 12),
            Row(
              children: [
                StoreActions(store: s, showSave: false, height: 34),
                const Spacer(),
                AppButton('매장 상세 ›', expand: false, height: 34, fontSize: 13, onPressed: onDetail),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        const EmojiImage('magnifier', size: 48),
        const SizedBox(height: 10),
        Text('조건에 맞는 매장이 없어요', style: AppText.body.copyWith(color: AppColors.sub)),
        const SizedBox(height: 4),
        Text('[재고 있는 곳만]을 끄면 더 많은 매장이 보여요', style: AppText.caption),
      ],
    ),
  );
}
