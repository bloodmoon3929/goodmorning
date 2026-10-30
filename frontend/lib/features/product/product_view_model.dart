import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';

enum ProductTab {
  online('온라인 가격'),
  offline('오프라인 매장'),
  similar('비슷한 굿즈');

  const ProductTab(this.label);
  final String label;
}

/// 15–16. 상품 상세 — 버전을 바꾸면 가격 · 재고가 그 버전 기준으로 바뀐다
class ProductViewModel extends ViewModel {
  ProductViewModel(this.state, this.productId, {String? variantId, this.tab = ProductTab.online}) : _variant = variantId {
    reload();
  }

  final AppState state;
  final String productId;
  String? _variant;
  ProductTab tab;
  bool inStockOnly = true;
  Load<ProductDetail> detail = const Loading();

  void reload() => load(() => state.api.product(productId), (v) => detail = v);

  Variant variant(ProductDetail d) => d.product.variant(_variant);

  void selectVariant(String id) {
    _variant = id;
    notify();
  }

  void setTab(ProductTab t) {
    tab = t;
    notify();
  }

  void toggleInStock() {
    inStockOnly = !inStockOnly;
    notify();
  }

  List<MallOffer> offers(ProductDetail d) => d.offersFor(variant(d).id);

  MallOffer? best(ProductDetail d) => offers(d).where((o) => !o.soldOut).firstOrNull;

  List<StoreStock> stocks(ProductDetail d) {
    final list = d.stocksFor(variant(d).id);
    return inStockOnly ? list.where((s) => s.status.inStock).toList() : list;
  }

  int nearbyInStock(ProductDetail d) => d.stocksFor(variant(d).id).where((s) => s.status.inStock).length;

  int onlineMalls(ProductDetail d) => offers(d).where((o) => !o.soldOut).length;
}
