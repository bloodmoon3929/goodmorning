import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../../models/search.dart';
import '../network/goodmorning_api.dart';

/// 미리 로딩 · 캐시 (docs/03-tech-spec.md 33번).
/// 한 번 받은 응답(Future)을 키별로 들고 있다가, 같은 요청이 오면 기다리지 않고 바로 돌려준다.
/// 홈이 뜬 뒤 다음에 갈 화면 데이터를 [prefetchAfterHome]으로 받아 둔다.
class CachedApi implements GoodmorningApi {
  CachedApi(this._api);

  final GoodmorningApi _api;
  final Map<String, Future<Object?>> _cache = {};

  Future<T> _get<T>(String key, Future<T> Function() load) {
    final hit = _cache[key];
    if (hit != null) return hit.then((v) => v as T);
    final f = load();
    _cache[key] = f;
    f.then<void>((_) {}, onError: (Object _) => _cache.remove(key)); // 실패한 응답은 남기지 않는다
    return f;
  }

  bool isCached(String key) => _cache.containsKey(key);

  void invalidate(String prefix) => _cache.removeWhere((k, _) => k.startsWith(prefix));

  /// 갈 가능성이 높은 화면부터 뒤에서 받아 둔다: 하단 탭 3개 첫 화면, 첫 번째 내 IP 화면, 첫 신상품 상세.
  Future<void> prefetchAfterHome(List<String> myIps) async {
    final ids = myIps.join(',');
    stores(myIps);
    ipStats(myIps);
    ips();
    notifications();
    if (myIps.isNotEmpty) ip(myIps.first);
    final news = await newProducts(myIps);
    if (news.isNotEmpty) product(news.first.product.id);
    _cache.putIfAbsent('prefetched:$ids', () => Future.value(true));
  }

  @override
  Future<List<Ip>> ips() => _get('ips', _api.ips);

  @override
  Future<List<IpStat>> ipStats(List<String> ipIds) => _get('ipStats:${ipIds.join(',')}', () => _api.ipStats(ipIds));

  @override
  Future<List<ProductSummary>> newProducts(List<String> ipIds) => _get('new:${ipIds.join(',')}', () => _api.newProducts(ipIds));

  @override
  Future<List<StoreSummary>> nearbyStores(List<String> ipIds) => _get('nearby:${ipIds.join(',')}', () => _api.nearbyStores(ipIds));

  @override
  Future<List<StoreSummary>> stores(List<String> ipIds) => _get('stores:${ipIds.join(',')}', () => _api.stores(ipIds));

  @override
  Future<ProductDetail> product(String id) => _get('product:$id', () => _api.product(id));

  @override
  Future<List<ProductSummary>> products(List<String> ids) => _get('products:${ids.join(',')}', () => _api.products(ids));

  @override
  Future<StoreDetail> store(String id) => _get('store:$id', () => _api.store(id));

  @override
  Future<IpDetail> ip(String id) => _get('ip:$id', () => _api.ip(id));

  @override
  Future<CharacterDetail> character(String id) => _get('character:$id', () => _api.character(id));

  @override
  Future<SearchResult> search(SearchQuery query, List<String> ipIds) => _get('search:${query.cacheKey}:${ipIds.join(',')}', () => _api.search(query, ipIds));

  @override
  Future<List<NotificationItem>> notifications() => _get('notifications', _api.notifications);

  @override
  Future<List<SamplePhoto>> recentPhotos() => _get('photos', _api.recentPhotos);

  @override
  Future<PhotoSearchResult> photoSearch(String photoId, {String condition = ''}) =>
      _get('photo:$photoId:$condition', () => _api.photoSearch(photoId, condition: condition));

  // 판매자 화면 · 쓰기 요청은 항상 새로 보낸다
  @override
  Future<SellerStore> sellerStore(String storeId) => _api.sellerStore(storeId);

  @override
  Future<List<RegisterCandidate>> registerCandidates(String photoId) => _get('candidates:$photoId', () => _api.registerCandidates(photoId));

  @override
  Future<bool> isEmailTaken(String email) => _api.isEmailTaken(email);

  @override
  Future<void> sendStockReport({required String storeId, required String productId, required String variantId, required StockStatus status}) =>
      _api.sendStockReport(storeId: storeId, productId: productId, variantId: variantId, status: status);

  @override
  Future<void> sendIssue({required String visitId, required String type, required String message}) =>
      _api.sendIssue(visitId: visitId, type: type, message: message);

  @override
  Future<void> saveInventory({required String storeId, required Map<String, StockStatus> changes}) async {
    await _api.saveInventory(storeId: storeId, changes: changes);
    invalidate('store:$storeId');
  }
}
