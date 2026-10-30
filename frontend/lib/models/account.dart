import 'dart:ui' show Color;

import 'catalog.dart';
import 'sales.dart';

/// account 스키마: 회원
class UserProfile {
  const UserProfile({required this.nickname, required this.email, required this.region});

  final String nickname;
  final String email;
  final String region;
}

/// 알림 종류 (알림 목록의 분류 칩)
enum NotificationType {
  price('가격', 'chart_down'),
  restock('재입고', 'package'),
  arrival('입고', 'pin'),
  report('제보 · 문의', 'check'),
  inquiry('제보 · 문의', 'speech'),
  newGoods('입고', 'star');

  const NotificationType(this.group, this.emoji);
  final String group;
  final String emoji;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.thisWeek,
    this.productId,
    this.storeId,
    this.ipId,
    this.thumbEmoji,
    this.thumbBg,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String timeLabel;
  final bool thisWeek; // false: 오늘
  final String? productId;
  final String? storeId;
  final String? ipId;
  final String? thumbEmoji; // 굿즈 알림은 사진을 함께 보여 준다
  final Color? thumbBg;
}

/// account 스키마: 이동 기록 — 구매하러 가기를 누른 시점의 몰 · 가격
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.whenLabel,
    required this.mall,
    required this.productId,
    required this.variantId,
    required this.variantLabel,
    required this.total,
    required this.priceLabel,
    this.purchased = false,
  });

  final String id;
  final String whenLabel;
  final String mall;
  final String productId;
  final String variantId;
  final String variantLabel;
  final int total; // 당시 배송비 포함 총액
  final String priceLabel; // 당시 39,800원 · 무료배송
  final bool purchased;

  VisitRecord copyWith({bool? purchased}) => VisitRecord(
    id: id,
    whenLabel: whenLabel,
    mall: mall,
    productId: productId,
    variantId: variantId,
    variantLabel: variantLabel,
    total: total,
    priceLabel: priceLabel,
    purchased: purchased ?? this.purchased,
  );
}

/// 내 제보 · 문의 내역 한 줄
class MyRecord {
  const MyRecord({
    required this.whenLabel,
    required this.title,
    required this.body,
    required this.status,
    this.done = false,
    this.storeId,
    this.productId,
    this.answer,
  });

  final String whenLabel;
  final String title; // 매장 이름 · 문의 제목
  final String body; // 굿즈 · 버전 · 제보한 재고, 문의 내용
  final String status; // 반영됨 · 반영 대기 · 답변 완료 …
  final bool done;
  final String? storeId;
  final String? productId;
  final String? answer; // 문의 답변
}

/// 사진 검색에 쓰는 사진 (프로토타입: 앨범의 최근 사진)
class SamplePhoto {
  const SamplePhoto({required this.id, required this.label, required this.emoji, required this.bg});

  final String id;
  final String label;
  final String emoji;
  final Color bg;
}

/// 사진 검색 결과 한 줄. 같은 groupId = 같은 굿즈의 다른 버전
class PhotoMatch {
  const PhotoMatch({required this.summary, required this.variant, required this.similarity, required this.groupId});

  final ProductSummary summary;
  final Variant variant;
  final int similarity; // %
  final String groupId;
}

class PhotoSearchResult {
  const PhotoSearchResult({required this.photo, required this.matches, this.versionWarning});

  final SamplePhoto photo;
  final List<PhotoMatch> matches;
  final String? versionWarning; // 같은 굿즈의 다른 버전이 위에 함께 나오면 안내
}

/// 판매자 센터: 재고 관리 한 줄
class InventoryItem {
  const InventoryItem({required this.product, required this.variant, required this.status});

  final Product product;
  final Variant variant;
  final StockStatus status;

  String get key => '${product.id}/${variant.id}';
}

class SellerStore {
  const SellerStore({required this.store, required this.items, required this.totalItems, required this.lastConfirmed, required this.pendingReports});

  final Store store;
  final List<InventoryItem> items;
  final int totalItems;
  final String lastConfirmed;
  final int pendingReports;
}

/// 판매자 센터 상품 등록: AI가 찾은 후보
class RegisterCandidate {
  const RegisterCandidate({required this.product, required this.variant, required this.similarity});

  final Product product;
  final Variant variant;
  final int similarity;
}
