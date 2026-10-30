import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/account.dart';
import '../../models/sales.dart';

/// 판매자 센터에 들어온 제보 한 줄 (사장님이 반영하거나 넘긴다)
class SellerReport {
  const SellerReport({required this.item, required this.status, required this.label});

  final InventoryItem item;
  final StockStatus status;
  final String label; // 제보 1건 · 어제
}

/// 24. 재고 관리 / 25. 상품 등록 — 사장님 계정 · 마이 → 판매자 센터
class SellerViewModel extends ViewModel {
  SellerViewModel(this.state) {
    reload();
  }

  final AppState state;
  static const myStores = ['yongsan', 'hongdae']; // 사장님이 관리하는 매장

  String storeId = myStores.first;
  Load<SellerStore> store = const Loading();
  List<InventoryItem> items = [];
  String lastConfirmed = '';
  int totalItems = 0;
  List<SellerReport> reports = [];
  final Map<String, StockStatus> edits = {}; // 바꾼 줄만
  bool saving = false;

  // 상품 등록
  String? photoId;
  Load<List<RegisterCandidate>>? candidates;
  int? picked;
  String name = '';
  StockStatus newStatus = StockStatus.many;
  String price = '';

  void reload() => load(() => state.api.sellerStore(storeId), (Load<SellerStore> v) {
    store = v;
    if (v case Loaded(:final value)) {
      items = [...value.items];
      lastConfirmed = value.lastConfirmed;
      totalItems = value.totalItems;
      edits.clear();
      // 들어온 제보 (목업): 사장님 확인 전 재고 제보
      const sample = [(3, StockStatus.none, '제보 1건 · 어제 18:20'), (5, StockStatus.few, '제보 1건 · 오늘 09:10')];
      reports = [
        for (final (i, s, label) in sample.take(value.pendingReports))
          if (i < items.length) SellerReport(item: items[i], status: s, label: label),
      ];
    }
  });

  void switchStore(String id) {
    if (id == storeId) return;
    storeId = id;
    reload();
  }

  StockStatus statusOf(InventoryItem item) => edits[item.key] ?? item.status;
  bool changed(InventoryItem item) => edits.containsKey(item.key);

  void setStatus(InventoryItem item, StockStatus s) {
    s == item.status ? edits.remove(item.key) : edits[item.key] = s;
    notify();
  }

  /// [오늘 재고 그대로예요]: 상태는 그대로, 전 품목 확인 시각만 지금으로
  Future<void> confirmAll() async {
    saving = true;
    notify();
    await state.api.saveInventory(storeId: storeId, changes: const {});
    lastConfirmed = '방금 전';
    saving = false;
    notify();
  }

  /// [변경 저장 (N건)]
  Future<int> save() async {
    final n = edits.length;
    saving = true;
    notify();
    await state.api.saveInventory(storeId: storeId, changes: Map.of(edits));
    items = [for (final it in items) InventoryItem(product: it.product, variant: it.variant, status: statusOf(it))];
    edits.clear();
    lastConfirmed = '방금 전';
    saving = false;
    notify();
    return n;
  }

  /// 제보 반영: 재고 관리의 해당 줄을 바꾼 상태로 (저장은 [변경 저장]에서)
  void applyReport(SellerReport r) {
    reports.remove(r);
    final it = items.firstWhere((x) => x.key == r.item.key);
    setStatus(it, r.status);
  }

  void dismissReport(SellerReport r) {
    reports.remove(r);
    notify();
  }

  // ------------------------------------------------------------ 상품 등록
  void pickPhoto(String id) {
    photoId = id;
    picked = 0;
    candidates = const Loading();
    notify();
    load(() => state.api.registerCandidates(id), (v) => candidates = v);
  }

  void pick(int i) {
    picked = i;
    notify();
  }

  void setName(String v) => name = v;

  void setNewStatus(StockStatus s) {
    newStatus = s;
    notify();
  }

  void setPrice(String v) {
    price = v;
    notify();
  }

  RegisterCandidate? get pickedCandidate {
    final list = candidates?.valueOrNull;
    if (list == null || picked == null || picked! >= list.length) return null;
    return list[picked!];
  }

  /// 위 두 후보가 같은 굿즈의 다른 버전이면 안내
  String? get versionWarning {
    final list = candidates?.valueOrNull;
    if (list == null || list.length < 2) return null;
    final (a, b) = (list[0], list[1]);
    if (a.product.id != b.product.id || (a.similarity - b.similarity).abs() > 5) return null;
    return '${a.variant.label}과(와) ${b.variant.label}은(는) 사진이 비슷해요.\n박스 · 크기 표기를 확인하세요.';
  }

  bool get canRegister => pickedCandidate != null && !saving;

  /// [내 매장에 추가]: 재고 관리 목록 맨 위에 넣는다. 이미 있는 굿즈면 상태만 바꾼다.
  Future<String> register() async {
    final c = pickedCandidate!;
    saving = true;
    notify();
    await state.api.saveInventory(storeId: storeId, changes: {'${c.product.id}/${c.variant.id}': newStatus});
    final item = InventoryItem(product: c.product, variant: c.variant, status: newStatus);
    final i = items.indexWhere((x) => x.key == item.key);
    if (i >= 0) {
      items[i] = item;
    } else {
      items.insert(0, item);
      totalItems++;
    }
    photoId = null;
    candidates = null;
    picked = null;
    name = '';
    price = '';
    newStatus = StockStatus.many;
    saving = false;
    notify();
    return '${c.product.name} · ${c.variant.label}';
  }
}
