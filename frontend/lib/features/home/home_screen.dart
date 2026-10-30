import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_filter/channel_filter.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/ip_tile/ip_tile.dart';
import '../../components/photo_pick/photo_pick_sheet.dart';
import '../../components/product_card/product_card.dart';
import '../../components/section_header/section_header.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import 'home_view_model.dart';
import 'widgets/nearby_store_card.dart';

/// 7. 홈 — 앱을 열면 처음 보이는 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final vm = HomeViewModel(AppScope.read(context));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context); // 내 IP · 필터가 바뀌면 다시 그린다
    vm.loadIfNeeded();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final id = await showPhotoPickSheet(context);
    if (id != null && mounted) context.push('/photo-search/$id');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final offlineFirst = state.channel == Channel.offline;
            final sections = <Widget>[if (offlineFirst) ..._stores() else ..._myIps(), if (offlineFirst) ..._myIps() else ..._stores(), ..._newGoods()];
            return RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () {
                state.api.invalidate('new:');
                state.api.invalidate('nearby:');
                return vm.refresh();
              },
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [_top(state), ...sections]),
            );
          },
        ),
      ),
    );
  }

  Widget _top(AppState state) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
    child: Column(
      children: [
        Row(
          children: [
            Text('굿모닝', style: AppText.display.copyWith(fontSize: 24, color: AppColors.orange)),
            const Spacer(),
            IconButton(
              tooltip: '알림',
              onPressed: () => context.push('/notifications'),
              icon: Badge(isLabelVisible: state.unreadCount > 0, smallSize: 8, backgroundColor: AppColors.orange, child: const EmojiImage('bell', size: 28)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Material(
            color: AppColors.bg,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/home/search'),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(18, 13, 8, 13),
                      child: Text('굿즈 이름, 캐릭터 검색', style: TextStyle(fontSize: 14, color: AppColors.sub)),
                    ),
                  ),
                ),
                IconButton(tooltip: '사진으로 찾기', onPressed: _photo, icon: const EmojiImage('camera', size: 24)),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(padding: EdgeInsets.only(right: 10), child: ChannelFilter()),
      ],
    ),
  );

  List<Widget> _myIps() => [
    SectionHeader('내 IP', more: '전체', onMore: () => context.go('/explore')),
    LoadView<List<Ip>>(
      load: vm.myIps,
      onRetry: vm.refresh,
      skeleton: const SkeletonTiles(),
      builder: (ips) => SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final ip in ips) IpTileSmall(ip: ip, onTap: () => context.go('/explore/ip/${ip.id}')),
            AddTileSmall(onTap: () => context.push('/ip-manage')),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _stores() => [
    SectionHeader('내 주변 재고', more: '지도', onMore: () => context.go('/stores?view=map')),
    LoadView<List<StoreSummary>>(
      load: vm.nearby,
      onRetry: vm.refresh,
      skeleton: const SkeletonCards(),
      builder: (stores) => SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: stores.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: 173,
            child: NearbyStoreCard(item: stores[i], onTap: () => context.go('/stores/${stores[i].store.id}')),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _newGoods() => [
    SectionHeader('내 IP 신상품', more: '더보기', onMore: () => context.push('/home/search?sort=newest')),
    LoadView<List<ProductSummary>>(
      load: vm.newGoods,
      onRetry: vm.refresh,
      skeleton: const SkeletonProductGrid(rows: 2),
      builder: (all) {
        final list = vm.filtered(all);
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('이 판매 경로의 신상품이 없어요', style: AppText.caption)),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 18, mainAxisExtent: 238),
          itemCount: list.length,
          itemBuilder: (_, i) => ProductCard(item: list[i], onTap: () => context.push('/product/${list[i].product.id}')),
        );
      },
    ),
  ];
}
