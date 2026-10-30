import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';

/// 17–18. 매장 찾기 — 리스트와 지도는 같은 결과를 표시만 바꾼다
class StoreFinderViewModel extends ViewModel {
  StoreFinderViewModel(this.state, {bool map = false}) : showMap = map {
    reload();
  }

  final AppState state;
  bool showMap;
  bool inStockOnly = true;
  bool includePopup = true;
  String query = '';
  String region = '용산구 한강로';
  String? selectedId; // 지도에서 고른 마커
  Load<List<StoreSummary>> stores = const Loading();

  void reload() => load(() => state.api.stores(state.myIps), (v) => stores = v);

  void setMap(bool v) {
    showMap = v;
    notify();
  }

  void toggleInStock() {
    inStockOnly = !inStockOnly;
    notify();
  }

  void togglePopup() {
    includePopup = !includePopup;
    notify();
  }

  void setQuery(String v) {
    query = v;
    notify();
  }

  void setRegion(String v) {
    region = v;
    notify();
  }

  void select(String? id) {
    selectedId = id;
    notify();
  }

  List<StoreSummary> visible(List<StoreSummary> all) {
    final q = query.trim();
    return all.where((s) {
      if (inStockOnly && s.myIpStock == 0 && !s.worstUnknown) return false;
      if (!includePopup && s.store.isPopup) return false;
      if (q.isNotEmpty && !s.store.name.contains(q) && !s.store.address.contains(q)) return false;
      return true;
    }).toList();
  }
}

/// 19–20. 매장 상세 · 재고 제보
class StoreDetailViewModel extends ViewModel {
  StoreDetailViewModel(this.state, this.storeId) {
    reload();
  }

  final AppState state;
  final String storeId;
  Load<StoreDetail> detail = const Loading();
  final Map<String, (StockStatus, String)> myReports = {}; // 보낸 제보: 반영 대기

  void reload() => load(() => state.api.store(storeId), (v) => detail = v);

  Future<void> report(Product p, Variant v, StockStatus status) async {
    await state.api.sendStockReport(storeId: storeId, productId: p.id, variantId: v.id, status: status);
    myReports['${p.id}/${v.id}'] = (status, '방금 제보 · 반영 대기');
    state.addReport(
      MyRecord(
        whenLabel: state.todayLabel,
        title: detail.valueOrNull?.store.name ?? '',
        body: '${p.name} · ${v.label} · 재고 ${status.short}',
        status: '반영 대기',
        storeId: storeId,
        productId: p.id,
      ),
    );
    notify();
  }
}
