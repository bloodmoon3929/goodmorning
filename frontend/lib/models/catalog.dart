import 'dart:ui' show Color;

/// IP 분류 (회원가입 IP 고르기 · IP 목록 조정의 분류 칩)
enum IpKind {
  character('캐릭터'),
  anime('애니'),
  game('게임'),
  plamodel('프라모델');

  const IpKind(this.label);
  final String label;
}

/// 품목 (굿즈 탐색의 품목으로 보기)
enum GoodsCategory {
  figure('피규어', 'moai'),
  doll('인형', 'teddy'),
  keyring('키링', 'key'),
  acrylic('아크릴', 'placard'),
  plamodel('프라모델', 'robot'),
  random('랜덤', 'die');

  const GoodsCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// catalog 스키마: IP
class Ip {
  const Ip({required this.id, required this.name, required this.emoji, required this.bg, required this.kind, this.shortName, this.aliases = const []});

  final String id;
  final String name;
  final String? shortName; // 홈 타일처럼 좁은 곳 (기동전사 건담 → 건담)
  final String emoji;
  final Color bg;
  final IpKind kind;
  final List<String> aliases;

  String get tileName => shortName ?? name;
}

/// catalog 스키마: 캐릭터 (상품과 N:M)
class Character {
  const Character({required this.id, required this.ipId, required this.name, required this.emoji, required this.bg, this.aliases = const []});

  final String id;
  final String ipId;
  final String name;
  final String emoji;
  final Color bg;
  final List<String> aliases;
}

/// catalog 스키마: 버전 — 가격과 재고는 버전 단위로 관리한다
class Variant {
  const Variant(this.id, this.label);
  final String id;
  final String label;
}

/// catalog 스키마: 상품
class Product {
  const Product({
    required this.id,
    required this.ipId,
    required this.characterIds,
    required this.name,
    required this.category,
    required this.emoji,
    required this.bg,
    required this.variants,
    this.popularity = 0,
    this.newRank = 99,
  });

  final String id;
  final String ipId;
  final List<String> characterIds;
  final String name;
  final GoodsCategory category;
  final String emoji;
  final Color bg;
  final List<Variant> variants;
  final int popularity; // 인기순
  final int newRank; // 신상품순 (작을수록 최근)

  Variant variant(String? id) => variants.firstWhere((v) => v.id == id, orElse: () => variants.first);
}

/// 목록 · 카드에 보이는 판매 경로 요약 (상품 카드의 배지 두 개)
class ChannelSummary {
  const ChannelSummary({this.onlineMalls = 0, this.minTotal, this.nearbyStores = 0, this.nearestKm});

  final int onlineMalls; // 온라인: 판매 몰 수
  final int? minTotal; // 배송비 포함 최저 총액
  final int nearbyStores; // 오프라인: 근처 재고 있는 매장 수
  final double? nearestKm;

  bool get hasOnline => onlineMalls > 0 && minTotal != null;
  bool get hasOffline => nearbyStores > 0;
}

/// 목록에서 쓰는 상품 한 줄 (상품 + IP · 캐릭터 이름 + 판매 경로 요약)
class ProductSummary {
  const ProductSummary({required this.product, required this.ipName, required this.characterNames, required this.channels});

  final Product product;
  final String ipName;
  final List<String> characterNames;
  final ChannelSummary channels;

  String get meta => '$ipName · ${characterNames.join(', ')}';
}
