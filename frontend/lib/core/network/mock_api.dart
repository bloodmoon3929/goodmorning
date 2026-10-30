import 'dart:math';

import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../../models/search.dart';
import 'goodmorning_api.dart';
import 'mock_data.dart';

/// 목업 데이터로 답하는 API. 서버 응답처럼 조금씩 늦게 와서 스켈레톤 · 부분 로딩을 볼 수 있다.
class MockGoodmorningApi implements GoodmorningApi {
  MockGoodmorningApi({this.latency = true, int seed = 7}) : _rand = Random(seed);

  final bool latency;
  final Random _rand;
  static const nearbyKm = 7.0; // 내 주변 재고로 보는 거리

  Future<void> _wait([int base = 350, int spread = 550]) async {
    if (!latency) return;
    await Future<void>.delayed(Duration(milliseconds: base + _rand.nextInt(spread)));
  }

  // ------------------------------------------------------------ 조회 도우미
  Ip _ip(String id) => MockData.ips.firstWhere((e) => e.id == id);
  Character _character(String id) => MockData.characters.firstWhere((e) => e.id == id);
  Product _product(String id) => MockData.products.firstWhere((e) => e.id == id);
  Store _store(String id) => MockData.stores.firstWhere((e) => e.id == id);

  ChannelSummary _channels(Product p) {
    final offers = (MockData.offers[p.id] ?? const <MallOffer>[]).where((o) => !o.soldOut).toList();
    final malls = offers.map((o) => o.mall).toSet();
    final minTotal = offers.isEmpty ? null : offers.map((o) => o.total).reduce(min);
    final stocked = MockData.stocks
        .where((s) => s.productId == p.id && s.status.inStock)
        .map((s) => _store(s.storeId))
        .where((s) => s.distanceKm <= nearbyKm)
        .toSet();
    final nearest = stocked.isEmpty ? null : stocked.map((s) => s.distanceKm).reduce(min);
    return ChannelSummary(onlineMalls: malls.length, minTotal: minTotal, nearbyStores: stocked.length, nearestKm: nearest);
  }

  ProductSummary _summary(Product p) =>
      ProductSummary(product: p, ipName: _ip(p.ipId).name, characterNames: p.characterIds.map((c) => _character(c).name).toList(), channels: _channels(p));

  StoreSummary _storeSummary(Store s, List<String> ipIds) {
    final stocks = MockData.stocks.where((x) => x.storeId == s.id).toList();
    final mine = stocks.where((x) => ipIds.contains(_product(x.productId).ipId)).toList();
    final inStock = mine.where((x) => x.status.inStock).length;
    final unknown = mine.isNotEmpty && mine.every((x) => x.status == StockStatus.check);
    return StoreSummary(store: s, myIpStock: inStock, worstUnknown: unknown || mine.isEmpty);
  }

  // ------------------------------------------------------------ API
  @override
  Future<List<Ip>> ips() async {
    await _wait(200, 300);
    return MockData.ips;
  }

  @override
  Future<List<IpStat>> ipStats(List<String> ipIds) async {
    await _wait();
    return [
      for (final id in ipIds) IpStat(ip: _ip(id), characterCount: MockData.characters.where((c) => c.ipId == id).length, goodsCount: _goodsCountLabel(id)),
    ];
  }

  /// PPT 예시의 굿즈 수 (산리오 128, 치이카와 86 …). 목업 상품 수보다 크게 보여 준다.
  int _goodsCountLabel(String ipId) =>
      const {'sanrio': 128, 'chiikawa': 86, 'pokemon': 210, 'gundam': 64, 'danbo': 12, 'fate': 9}[ipId] ??
      MockData.products.where((p) => p.ipId == ipId).length;

  @override
  Future<List<ProductSummary>> newProducts(List<String> ipIds) async {
    await _wait(500, 700);
    final list = MockData.products.where((p) => ipIds.contains(p.ipId)).toList()..sort((a, b) => a.newRank.compareTo(b.newRank));
    return list.take(8).map(_summary).toList();
  }

  @override
  Future<List<StoreSummary>> nearbyStores(List<String> ipIds) async {
    await _wait(300, 600);
    return (await _storesSorted(ipIds)).take(3).toList();
  }

  @override
  Future<List<StoreSummary>> stores(List<String> ipIds) async {
    await _wait();
    return _storesSorted(ipIds);
  }

  Future<List<StoreSummary>> _storesSorted(List<String> ipIds) async {
    final list = MockData.stores.map((s) => _storeSummary(s, ipIds)).toList();
    list.sort((a, b) => a.store.distanceKm.compareTo(b.store.distanceKm));
    return list;
  }

  @override
  Future<ProductDetail> product(String id) async {
    await _wait();
    final p = _product(id);
    final stocks = MockData.stocks.where((s) => s.productId == id).toList();
    final similar = MockData.products.where((x) => x.id != id && (x.ipId == p.ipId || x.category == p.category)).toList()
      ..sort((a, b) {
        int score(Product x) => (x.characterIds.any(p.characterIds.contains) ? 2 : 0) + (x.category == p.category ? 1 : 0);
        return score(b).compareTo(score(a));
      });
    return ProductDetail(
      product: p,
      ipName: _ip(p.ipId).name,
      characters: p.characterIds.map(_character).toList(),
      offers: MockData.offers[id] ?? const [],
      stocks: stocks,
      stores: {for (final s in MockData.stores) s.id: s},
      similar: similar.take(4).map(_summary).toList(),
    );
  }

  @override
  Future<List<ProductSummary>> products(List<String> ids) async {
    await _wait(250, 400);
    return [for (final id in ids) _summary(_product(id))];
  }

  @override
  Future<StoreDetail> store(String id) async {
    await _wait();
    final items = MockData.stocks.where((s) => s.storeId == id).map((s) {
      final p = _product(s.productId);
      return StoreStockItem(product: p, variant: p.variant(s.variantId), stock: s);
    }).toList();
    return StoreDetail(store: _store(id), items: items);
  }

  @override
  Future<IpDetail> ip(String id) async {
    await _wait();
    final products = MockData.products.where((p) => p.ipId == id).toList()..sort((a, b) => b.popularity.compareTo(a.popularity));
    return IpDetail(ip: _ip(id), characters: MockData.characters.where((c) => c.ipId == id).toList(), products: products.map(_summary).toList());
  }

  @override
  Future<CharacterDetail> character(String id) async {
    await _wait();
    final c = _character(id);
    final groups = <GoodsCategory, List<ProductSummary>>{};
    for (final p in MockData.products.where((p) => p.characterIds.contains(id))) {
      groups.putIfAbsent(p.category, () => []).add(_summary(p));
    }
    return CharacterDetail(character: c, ip: _ip(c.ipId), groups: groups);
  }

  @override
  Future<SearchResult> search(SearchQuery q, List<String> ipIds) async {
    await _wait();
    final text = q.text.trim().toLowerCase();
    (String, String)? alias;
    final ipHits = <Ip>[];
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // 별칭: 먼작귀 → 치이카와처럼 다른 이름으로도 함께 찾는다
    for (final ip in MockData.ips) {
      for (final a in ip.aliases) {
        if (words.any((w) => a.toLowerCase().contains(w) || w.contains(a.toLowerCase())) && a.toLowerCase() != ip.name.toLowerCase()) {
          alias ??= (a, ip.name);
        }
      }
      if (words.any((w) => ip.name.toLowerCase().contains(w) || ip.aliases.any((a) => a.toLowerCase().contains(w)))) ipHits.add(ip);
    }

    bool matches(Product p) {
      if (words.isEmpty) return true;
      final ip = _ip(p.ipId);
      final chars = p.characterIds.map(_character);
      final hay = [
        p.name,
        ip.name,
        ...ip.aliases,
        p.category.label,
        for (final c in chars) ...[c.name, ...c.aliases],
      ].join(' ').toLowerCase();
      return words.every((w) => hay.contains(w));
    }

    var list = MockData.products.where(matches).map(_summary).toList();
    if (q.category != null) list = list.where((s) => s.product.category == q.category).toList();
    if (q.price.max != null) list = list.where((s) => s.channels.minTotal != null && s.channels.minTotal! <= q.price.max!).toList();
    switch (q.sort) {
      case SearchSort.lowest:
        list.sort((a, b) => (a.channels.minTotal ?? 1 << 30).compareTo(b.channels.minTotal ?? 1 << 30));
      case SearchSort.nearest:
        list.sort((a, b) => (a.channels.nearestKm ?? 999).compareTo(b.channels.nearestKm ?? 999));
      case SearchSort.newest:
        list.sort((a, b) => a.product.newRank.compareTo(b.product.newRank));
      case SearchSort.popular:
        list.sort((a, b) => b.product.popularity.compareTo(a.product.popularity));
    }
    return SearchResult(items: list, alias: alias, ips: ipHits);
  }

  @override
  Future<List<NotificationItem>> notifications() async {
    await _wait();
    return MockData.notifications;
  }

  @override
  Future<List<SamplePhoto>> recentPhotos() async {
    await _wait(150, 200);
    return MockData.photos;
  }

  @override
  Future<PhotoSearchResult> photoSearch(String photoId, {String condition = ''}) async {
    await _wait(600, 700); // 임베딩 검색은 조금 더 걸린다
    final photo = MockData.photos.firstWhere((p) => p.id == photoId);
    var matches = [
      for (final (pid, vid, sim) in MockData.photoMatches[photoId]!)
        PhotoMatch(summary: _summary(_product(pid)), variant: _product(pid).variant(vid), similarity: sim, groupId: pid),
    ];
    String? warning = MockData.photoWarnings[photoId];
    final cond = condition.trim().toLowerCase();
    if (cond.isNotEmpty) {
      // 사진에 글자 조건을 더해 다시 찾기: 조건이 맞는 버전을 위로 올리고 점수를 더한다
      bool hit(PhotoMatch m) =>
          cond.split(RegExp(r'\s+')).any((w) => m.variant.label.toLowerCase().contains(w) || m.summary.product.name.toLowerCase().contains(w));
      matches = [
        for (final m in matches)
          PhotoMatch(summary: m.summary, variant: m.variant, similarity: hit(m) ? min(99, m.similarity + 15) : m.similarity, groupId: m.groupId),
      ]..sort((a, b) => b.similarity.compareTo(a.similarity));
      if (matches.isNotEmpty && matches.length > 1 && matches[0].similarity - matches[1].similarity >= 8) warning = null;
    }
    return PhotoSearchResult(photo: photo, matches: matches, versionWarning: warning);
  }

  @override
  Future<SellerStore> sellerStore(String storeId) async {
    await _wait();
    final (total, last, reports) = MockData.sellerStores[storeId] ?? (0, '-', 0);
    final items = MockData.stocks.where((s) => s.storeId == storeId).map((s) {
      final p = _product(s.productId);
      return InventoryItem(product: p, variant: p.variant(s.variantId), status: s.status == StockStatus.check ? StockStatus.few : s.status);
    }).toList();
    return SellerStore(store: _store(storeId), items: items, totalItems: total, lastConfirmed: last, pendingReports: reports);
  }

  @override
  Future<List<RegisterCandidate>> registerCandidates(String photoId) async {
    await _wait(600, 600);
    return [
      for (final (pid, vid, sim) in MockData.photoMatches[photoId]!)
        RegisterCandidate(product: _product(pid), variant: _product(pid).variant(vid), similarity: sim),
    ];
  }

  @override
  Future<bool> isEmailTaken(String email) async {
    await _wait(250, 300);
    return email.trim().toLowerCase() == 'taken@example.com';
  }

  @override
  Future<void> sendStockReport({required String storeId, required String productId, required String variantId, required StockStatus status}) => _wait(400, 300);

  @override
  Future<void> sendIssue({required String visitId, required String type, required String message}) => _wait(400, 300);

  @override
  Future<void> saveInventory({required String storeId, required Map<String, StockStatus> changes}) => _wait(400, 300);
}
