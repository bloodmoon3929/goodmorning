import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/account.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';

/// 22. 이동 기록 · 구매 기록 · 찜 · 가격 알림 목록이 함께 쓰는 상품 조회.
/// 기록에는 상품 id만 있어서, 사진 · 이름은 한 번에 받아 온다.
class ProductLookupViewModel extends ViewModel {
  ProductLookupViewModel(this.state, this.ids) {
    reload();
  }

  final AppState state;
  final List<String> ids;
  Load<Map<String, ProductSummary>> products = const Loading();

  void reload() => load(() async => {for (final p in await state.api.products(ids.toSet().toList())) p.product.id: p}, (v) => products = v);
}

/// 23. 문제 제기: 당시 가격과 지금 가격을 함께 보낸다
class IssueViewModel extends ViewModel {
  IssueViewModel(this.state, this.visit, this.productName) {
    load(() async {
      final d = await state.api.product(visit.productId);
      return d.offersFor(visit.variantId).where((o) => o.mall == visit.mall && !o.soldOut).firstOrNull;
    }, (v) => nowOffer = v);
  }

  final AppState state;
  final VisitRecord visit;
  final String productName;
  static const types = ['가격이 달랐어요', '재고가 없었어요', '가품이 의심돼요', '기타'];

  String? type;
  String message = '';
  bool sending = false;
  Load<MallOffer?> nowOffer = const Loading();

  bool get canSend => type != null && !sending;

  void setType(String t) {
    type = t;
    notify();
  }

  void setMessage(String v) {
    message = v;
    notify();
  }

  Future<void> send() async {
    sending = true;
    notify();
    await state.api.sendIssue(visitId: visit.id, type: type!, message: message.trim());
    state.addInquiry(
      MyRecord(
        whenLabel: state.todayLabel,
        title: '${visit.mall} · $type',
        body: '$productName · ${visit.variantLabel}${message.trim().isEmpty ? '' : ' · ${message.trim()}'}',
        status: '답변 대기',
        productId: visit.productId,
      ),
    );
    sending = false;
    notify();
  }
}

/// 마이 → 저장한 매장
class SavedStoresViewModel extends ViewModel {
  SavedStoresViewModel(this.state) {
    reload();
  }

  final AppState state;
  Load<List<StoreSummary>> stores = const Loading();

  void reload() => load(() => state.api.stores(state.myIps), (v) => stores = v);
}
