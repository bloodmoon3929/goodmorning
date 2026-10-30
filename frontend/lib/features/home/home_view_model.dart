import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';

/// 7. 홈 — 내 IP / 내 주변 재고 / 신상품을 따로 요청해서 온 순서대로 채운다 (부분 로딩).
/// 다 뜬 뒤에는 다음 화면 데이터를 뒤에서 받아 둔다 (미리 로딩).
class HomeViewModel extends ViewModel {
  HomeViewModel(this.state);

  final AppState state;
  Load<List<Ip>> myIps = const Loading();
  Load<List<StoreSummary>> nearby = const Loading();
  Load<List<ProductSummary>> newGoods = const Loading();
  String _loadedFor = '';

  /// 내 IP가 바뀌었을 때만 다시 불러온다
  void loadIfNeeded() {
    final key = state.myIps.join(',');
    if (key == _loadedFor) return;
    _loadedFor = key;
    refresh();
  }

  Future<void> refresh() async {
    final ids = [...state.myIps];
    final api = state.api;
    await Future.wait([
      load(() async {
        final all = await api.ips();
        return [for (final id in ids) all.firstWhere((ip) => ip.id == id)];
      }, (v) => myIps = v),
      load(() => api.nearbyStores(ids), (v) => nearby = v),
      load(() => api.newProducts(ids), (v) => newGoods = v),
    ]);
    api.prefetchAfterHome(ids);
  }

  List<ProductSummary> filtered(List<ProductSummary> list) => switch (state.channel) {
    Channel.all => list,
    Channel.online => list.where((p) => p.channels.hasOnline).toList(),
    Channel.offline => list.where((p) => p.channels.hasOffline).toList(),
  };
}
