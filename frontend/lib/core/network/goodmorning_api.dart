import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../../models/search.dart';

/// 화면이 쓰는 API. 지금은 MockGoodmorningApi(목업 데이터)가 구현하고,
/// 단계 3에서 Rust API 서버가 생기면 같은 모양으로 HTTP 구현을 붙인다.
abstract interface class GoodmorningApi {
  Future<List<Ip>> ips();
  Future<List<IpStat>> ipStats(List<String> ipIds);
  Future<List<ProductSummary>> newProducts(List<String> ipIds);
  Future<List<StoreSummary>> nearbyStores(List<String> ipIds);
  Future<List<StoreSummary>> stores(List<String> ipIds);
  Future<ProductDetail> product(String id);
  Future<List<ProductSummary>> products(List<String> ids);
  Future<StoreDetail> store(String id);
  Future<IpDetail> ip(String id);
  Future<CharacterDetail> character(String id);
  Future<SearchResult> search(SearchQuery query, List<String> ipIds);
  Future<List<NotificationItem>> notifications();
  Future<List<SamplePhoto>> recentPhotos();
  Future<PhotoSearchResult> photoSearch(String photoId, {String condition = ''});
  Future<SellerStore> sellerStore(String storeId);
  Future<List<RegisterCandidate>> registerCandidates(String photoId);
  Future<bool> isEmailTaken(String email);
  Future<void> sendStockReport({required String storeId, required String productId, required String variantId, required StockStatus status});
  Future<void> sendIssue({required String visitId, required String type, required String message});
  Future<void> saveInventory({required String storeId, required Map<String, StockStatus> changes});
}
