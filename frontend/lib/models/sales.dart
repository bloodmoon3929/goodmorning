import 'catalog.dart';

/// 판매 경로 필터 (전체 / 온라인 / 오프라인)
enum Channel {
  all('전체'),
  online('온라인'),
  offline('오프라인');

  const Channel(this.label);
  final String label;
}

/// online 스키마: 몰별 가격 (버전 단위)
class MallOffer {
  const MallOffer({
    required this.mall,
    required this.variantId,
    required this.price,
    this.shipping = 0,
    required this.source,
    required this.checkedLabel,
    this.soldOut = false,
  });

  final String mall;
  final String variantId;
  final int price;
  final int shipping;
  final String source; // API · 수집
  final String checkedLabel; // 20분 전
  final bool soldOut;

  int get total => price + shipping;
}

/// 재고 상태 (공통 요소의 재고 배지)
enum StockStatus {
  many('재고 많음', '많음'),
  few('재고 적음', '적음'),
  none('재고 없음', '없음'),
  check('확인 필요', '확인 필요');

  const StockStatus(this.label, this.short);
  final String label;
  final String short;

  bool get inStock => this == many || this == few;
}

/// 재고를 누가 확인했는지
enum StockSource {
  owner('사장님 확인'),
  report('제보'),
  crawl('수집');

  const StockSource(this.label);
  final String label;
}

/// offline 스키마: 매장
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.kind,
    required this.distanceKm,
    required this.closesAt,
    required this.address,
    required this.hours,
    required this.phone,
    required this.infoSource,
    required this.mapX,
    required this.mapY,
    this.popupEnds,
    this.hasOwner = false,
  });

  final String id;
  final String name;
  final String kind; // 피규어·프라모델, 캐릭터샵, 팝업 …
  final double distanceKm;
  final String closesAt; // 20:30
  final String address;
  final String hours;
  final String phone;
  final String infoSource; // 정보 출처: 사장님 등록 · 10/28 갱신
  final double mapX; // 가상 지도 위 위치 (0~1)
  final double mapY;
  final String? popupEnds; // 팝업스토어 종료일
  final bool hasOwner; // 사장님이 있는 매장 (제보 반영 기준이 다름)

  bool get isPopup => popupEnds != null;
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)}km';
  String get openLabel => '$distanceLabel · 영업 중 · $closesAt까지';
}

/// offline 스키마: 매장별 재고 (버전 단위)
class StoreStock {
  const StoreStock({
    required this.storeId,
    required this.productId,
    required this.variantId,
    required this.status,
    required this.source,
    required this.checkedLabel,
  });

  final String storeId;
  final String productId;
  final String variantId;
  final StockStatus status;
  final StockSource source;
  final String checkedLabel;

  String get sourceLabel => '${source.label} · $checkedLabel';
}

/// 매장 목록의 한 줄 (내 IP 굿즈 재고 수 포함)
class StoreSummary {
  const StoreSummary({required this.store, required this.myIpStock, required this.worstUnknown});

  final Store store;
  final int myIpStock; // 내 IP 굿즈 재고 수
  final bool worstUnknown; // 재고를 알 수 없음 → "재고 확인 필요"

  /// 지도 마커 색: 재고 많음 · 적음 · 확인 필요
  StockStatus get markerStatus => worstUnknown ? StockStatus.check : (myIpStock >= 2 ? StockStatus.many : StockStatus.few);
}

/// 상품 상세 화면 데이터
class ProductDetail {
  const ProductDetail({
    required this.product,
    required this.ipName,
    required this.characters,
    required this.offers,
    required this.stocks,
    required this.stores,
    required this.similar,
  });

  final Product product;
  final String ipName;
  final List<Character> characters;
  final List<MallOffer> offers;
  final List<StoreStock> stocks;
  final Map<String, Store> stores;
  final List<ProductSummary> similar;

  List<MallOffer> offersFor(String variantId) {
    final list = offers.where((o) => o.variantId == variantId).toList();
    list.sort((a, b) {
      if (a.soldOut != b.soldOut) return a.soldOut ? 1 : -1;
      return a.total.compareTo(b.total);
    });
    return list;
  }

  List<StoreStock> stocksFor(String variantId) {
    final list = stocks.where((s) => s.variantId == variantId).toList();
    list.sort((a, b) => stores[a.storeId]!.distanceKm.compareTo(stores[b.storeId]!.distanceKm));
    return list;
  }
}

/// 매장 상세 화면 데이터
class StoreDetail {
  const StoreDetail({required this.store, required this.items});

  final Store store;
  final List<StoreStockItem> items;
}

class StoreStockItem {
  const StoreStockItem({required this.product, required this.variant, required this.stock});

  final Product product;
  final Variant variant;
  final StoreStock stock;
}
