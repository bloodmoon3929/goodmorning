import 'catalog.dart';

/// 정렬 (검색 결과 · IP 화면)
enum SearchSort {
  lowest('최저가순'),
  nearest('가까운 매장순'),
  newest('신상품순'),
  popular('인기순');

  const SearchSort(this.label);
  final String label;
}

/// 가격 조건 (검색 결과의 가격 ▾)
enum PriceRange {
  any('가격 전체', null),
  under10k('1만 원 이하', 10000),
  under20k('2만 원 이하', 20000),
  under40k('4만 원 이하', 40000);

  const PriceRange(this.label, this.max);
  final String label;
  final int? max;
}

class SearchQuery {
  const SearchQuery({this.text = '', this.category, this.price = PriceRange.any, this.sort = SearchSort.lowest});

  final String text;
  final GoodsCategory? category;
  final PriceRange price;
  final SearchSort sort;

  SearchQuery copyWith({String? text, GoodsCategory? category, bool clearCategory = false, PriceRange? price, SearchSort? sort}) =>
      SearchQuery(text: text ?? this.text, category: clearCategory ? null : (category ?? this.category), price: price ?? this.price, sort: sort ?? this.sort);

  String get cacheKey => '$text|${category?.name}|${price.name}|${sort.name}';
}

class SearchResult {
  const SearchResult({required this.items, this.alias, this.ips = const []});

  final List<ProductSummary> items;
  final (String, String)? alias; // ('먼작귀', '치이카와'): 별칭 안내
  final List<Ip> ips; // 이름 · 별칭이 맞은 IP
}

/// IP 화면 데이터
class IpDetail {
  const IpDetail({required this.ip, required this.characters, required this.products});

  final Ip ip;
  final List<Character> characters;
  final List<ProductSummary> products;
}

/// 캐릭터 화면 데이터: 품목별 묶음
class CharacterDetail {
  const CharacterDetail({required this.character, required this.ip, required this.groups});

  final Character character;
  final Ip ip;
  final Map<GoodsCategory, List<ProductSummary>> groups;

  int get goodsCount => groups.values.fold(0, (a, b) => a + b.length);
  int get onlineCount => groups.values.expand((e) => e).where((p) => p.channels.hasOnline).length;
  int get nearbyCount => groups.values.expand((e) => e).where((p) => p.channels.hasOffline).length;
}

/// 굿즈 탐색의 내 IP 타일: 캐릭터 수 · 굿즈 수
class IpStat {
  const IpStat({required this.ip, required this.characterCount, required this.goodsCount});

  final Ip ip;
  final int characterCount;
  final int goodsCount;
}
