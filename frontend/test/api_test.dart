import 'package:flutter_test/flutter_test.dart';
import 'package:goodmorning/core/cache/cached_api.dart';
import 'package:goodmorning/core/network/mock_api.dart';
import 'package:goodmorning/core/network/mock_data.dart';
import 'package:goodmorning/models/search.dart';

void main() {
  final api = MockGoodmorningApi(latency: false);
  const myIps = MockData.defaultMyIps;

  test('별칭으로 검색해도 정식 이름의 굿즈가 나온다', () async {
    final r = await api.search(const SearchQuery(text: '쿠로미'), myIps);
    expect(r.items, isNotEmpty);
    expect(r.items.every((s) => s.product.name.contains('쿠로미') || s.characterNames.contains('쿠로미')), isTrue);
  });

  test('매장 목록은 가까운 순', () async {
    final list = await api.stores(myIps);
    final d = list.map((s) => s.store.distanceKm).toList();
    expect(d, [...d]..sort());
  });

  test('최저가순 정렬은 배송비 포함 총액 기준', () async {
    final r = await api.search(const SearchQuery(sort: SearchSort.lowest), myIps);
    final totals = r.items.map((s) => s.channels.minTotal).whereType<int>().toList();
    expect(totals, [...totals]..sort());
  });

  test('캐시: 같은 요청은 같은 응답을 돌려주고, 재고 저장 뒤에는 매장 상세를 다시 받는다', () async {
    final cached = CachedApi(api);
    final a = cached.store('yongsan');
    expect(cached.isCached('store:yongsan'), isTrue);
    expect(identical(await a, await cached.store('yongsan')), isTrue);
    await cached.saveInventory(storeId: 'yongsan', changes: const {});
    expect(cached.isCached('store:yongsan'), isFalse);
  });
}
