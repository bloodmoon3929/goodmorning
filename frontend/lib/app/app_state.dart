import 'package:flutter/widgets.dart';

import '../core/cache/cached_api.dart';
import '../core/network/mock_data.dart';
import '../models/account.dart';
import '../models/sales.dart';

enum Session { none, guest, member }

/// 앱 전체가 함께 쓰는 사용자 상태: 로그인, 내 IP, 판매 경로 필터, 찜, 알림, 저장한 매장, 이동 기록.
/// (서버가 생기면 account 스키마로 저장되는 값들)
class AppState extends ChangeNotifier {
  AppState({required this.api});

  final CachedApi api;

  Session session = Session.none;
  UserProfile profile = MockData.profile;
  List<String> myIps = [...MockData.defaultMyIps];
  Channel channel = Channel.all;
  final Set<String> favorites = {'kuromi-mascot', 'chiikawa-key', 'kitty-doll', 'rg-rx78', 'usagi-kuji'};
  final Set<String> priceAlerts = {'kuromi-mascot', 'chiikawa-mascot', 'rg-rx78'};
  final Set<String> savedStores = {'yongsan', 'hongdae'};
  final Set<String> readNotifications = {
    for (final n in MockData.notifications)
      if (!MockData.unreadNotifications.contains(n.id)) n.id,
  };
  final List<VisitRecord> visits = [...MockData.visits];
  final List<MyRecord> reports = [...MockData.myReports];
  final List<MyRecord> inquiries = [...MockData.inquiries];
  bool isSeller = true; // 프로토타입: 사장님 계정으로 판매자 센터까지 볼 수 있게

  bool get isMember => session == Session.member;
  bool get started => session != Session.none;
  int get unreadCount => MockData.notifications.where((n) => !readNotifications.contains(n.id)).length;
  int get purchasedCount => visits.where((v) => v.purchased).length + 1; // + 매장에서 산 기록 1건

  void login({String? email}) {
    session = Session.member;
    if (email != null && email.isNotEmpty) {
      profile = UserProfile(nickname: profile.nickname, email: email, region: profile.region);
    }
    notifyListeners();
  }

  void signUp({required String email, required String nickname, required String region, required List<String> ips}) {
    session = Session.member;
    profile = UserProfile(nickname: nickname, email: email, region: region);
    myIps = [...ips];
    notifyListeners();
  }

  /// 웹 미리보기: 주소에 ?as=member 또는 ?as=guest 를 붙이면 로그인 단계를 건너뛰고 그 화면을 바로 연다.
  void startFrom(Uri url) {
    switch (url.queryParameters['as']) {
      case 'member':
        session = Session.member;
      case 'guest':
        session = Session.guest;
    }
  }

  void browseAsGuest() {
    session = Session.guest;
    notifyListeners();
  }

  void logout() {
    session = Session.none;
    notifyListeners();
  }

  void setChannel(Channel c) {
    if (c == channel) return;
    channel = c;
    notifyListeners();
  }

  void setMyIps(List<String> ids) {
    myIps = [...ids];
    notifyListeners();
  }

  void toggleFavorite(String productId) {
    favorites.contains(productId) ? favorites.remove(productId) : favorites.add(productId);
    notifyListeners();
  }

  void togglePriceAlert(String productId) {
    priceAlerts.contains(productId) ? priceAlerts.remove(productId) : priceAlerts.add(productId);
    notifyListeners();
  }

  void toggleSavedStore(String storeId) {
    savedStores.contains(storeId) ? savedStores.remove(storeId) : savedStores.add(storeId);
    notifyListeners();
  }

  void markRead(String id) {
    if (readNotifications.add(id)) notifyListeners();
  }

  void markAllRead() {
    readNotifications.addAll(MockData.notifications.map((n) => n.id));
    notifyListeners();
  }

  /// [구매하러 가기]: 앱 밖 몰로 나가기 전에 그때의 몰 · 가격을 이동 기록에 남긴다.
  VisitRecord recordVisit({required String productId, required String variantLabel, required MallOffer offer}) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final price = offer.shipping == 0 ? '당시 ${won(offer.price)} · 무료배송' : '당시 ${won(offer.price)} + 배송 ${won(offer.shipping)}';
    final rec = VisitRecord(
      id: 'v${now.microsecondsSinceEpoch}',
      whenLabel: '${now.month}/${now.day} ${two(now.hour)}:${two(now.minute)}',
      mall: offer.mall,
      productId: productId,
      variantId: offer.variantId,
      variantLabel: variantLabel,
      total: offer.total,
      priceLabel: price,
    );
    visits.insert(0, rec);
    notifyListeners();
    return rec;
  }

  void markPurchased(String visitId) {
    final i = visits.indexWhere((v) => v.id == visitId);
    if (i < 0) return;
    visits[i] = visits[i].copyWith(purchased: !visits[i].purchased);
    notifyListeners();
  }

  void addReport(MyRecord r) {
    reports.insert(0, r);
    notifyListeners();
  }

  void addInquiry(MyRecord r) {
    inquiries.insert(0, r);
    notifyListeners();
  }

  /// 10/30
  String get todayLabel => '${DateTime.now().month}/${DateTime.now().day}';
}

/// 12,900원
String won(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b원';
}

/// 위젯 트리 어디서든 AppState와 API를 꺼내 쓰게 하는 범위.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// 상태가 바뀌면 다시 그려야 하는 곳에서 쓴다.
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// 버튼 동작처럼 다시 그릴 필요가 없는 곳에서 쓴다.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
