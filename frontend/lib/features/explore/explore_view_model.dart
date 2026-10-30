import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/catalog.dart';
import '../../models/search.dart';

/// 8. 굿즈 탐색 — 내 IP 타일(캐릭터 수 · 굿즈 수)
class ExploreViewModel extends ViewModel {
  ExploreViewModel(this.state);

  final AppState state;
  Load<List<IpStat>> stats = const Loading();
  String _loadedFor = '';

  void loadIfNeeded() {
    final key = state.myIps.join(',');
    if (key == _loadedFor) return;
    _loadedFor = key;
    reload();
  }

  void reload() => load(() => state.api.ipStats(state.myIps), (v) => stats = v);
}

/// 13. IP 화면 — 캐릭터 선택 · 품목 필터 · 정렬
class IpViewModel extends ViewModel {
  IpViewModel(this.state, this.ipId) {
    reload();
  }

  final AppState state;
  final String ipId;
  Load<IpDetail> detail = const Loading();
  GoodsCategory? category;
  SearchSort sort = SearchSort.popular;

  void reload() => load(() => state.api.ip(ipId), (v) => detail = v);

  void setCategory(GoodsCategory? c) {
    category = c;
    notify();
  }

  void setSort(SearchSort s) {
    sort = s;
    notify();
  }

  List<ProductSummary> visible(IpDetail d) {
    var list = d.products.where((p) => category == null || p.product.category == category).toList();
    list = switch (state.channel.name) {
      'online' => list.where((p) => p.channels.hasOnline).toList(),
      'offline' => list.where((p) => p.channels.hasOffline).toList(),
      _ => list,
    };
    switch (sort) {
      case SearchSort.lowest:
        list.sort((a, b) => (a.channels.minTotal ?? 1 << 30).compareTo(b.channels.minTotal ?? 1 << 30));
      case SearchSort.newest:
        list.sort((a, b) => a.product.newRank.compareTo(b.product.newRank));
      case SearchSort.nearest:
        list.sort((a, b) => (a.channels.nearestKm ?? 999).compareTo(b.channels.nearestKm ?? 999));
      case SearchSort.popular:
        list.sort((a, b) => b.product.popularity.compareTo(a.product.popularity));
    }
    return list;
  }

  /// 이 IP에 있는 품목만 칩으로 보인다
  List<GoodsCategory> categories(IpDetail d) => GoodsCategory.values.where((c) => d.products.any((p) => p.product.category == c)).toList();
}

/// 14. 캐릭터 화면 — 한 캐릭터의 키링 · 인형 · 아크릴을 한 화면에
class CharacterViewModel extends ViewModel {
  CharacterViewModel(this.state, this.characterId) {
    reload();
  }

  final AppState state;
  final String characterId;
  Load<CharacterDetail> detail = const Loading();

  void reload() => load(() => state.api.character(characterId), (v) => detail = v);
}
