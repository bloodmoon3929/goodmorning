import 'dart:async';

import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../../models/search.dart';

/// 10. 검색 결과 — 글자 검색 · 별칭 안내 · 품목 · 가격 · 정렬
class SearchViewModel extends ViewModel {
  SearchViewModel(this.state, {String text = '', GoodsCategory? category, SearchSort sort = SearchSort.lowest})
    : query = SearchQuery(text: text, category: category, sort: sort) {
    if (text.isNotEmpty || category != null || sort != SearchSort.lowest) run();
  }

  final AppState state;
  SearchQuery query;
  Load<SearchResult>? result; // null: 아직 검색 전
  Timer? _debounce;

  static const recent = ['먼작귀 키링', '쿠로미', '건담 RG', '단보'];
  static const popular = ['치이카와', '피카츄 인형', '산리오 키링', '세이버 피규어', '헬로키티'];

  bool get hasCondition => query.text.trim().isNotEmpty || query.category != null || query.sort != SearchSort.lowest;

  void typed(String text) {
    query = query.copyWith(text: text);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), run);
    notify();
  }

  void submit(String text) {
    _debounce?.cancel();
    query = query.copyWith(text: text);
    run();
  }

  void setCategory(GoodsCategory? c) {
    query = c == null ? query.copyWith(clearCategory: true) : query.copyWith(category: c);
    run();
  }

  void setPrice(PriceRange p) {
    query = query.copyWith(price: p);
    run();
  }

  void setSort(SearchSort s) {
    query = query.copyWith(sort: s);
    run();
  }

  void run() {
    if (!hasCondition) {
      result = null;
      notify();
      return;
    }
    load(() => state.api.search(query, state.myIps), (v) => result = v);
  }

  List<ProductSummary> filtered(List<ProductSummary> list) => switch (state.channel) {
    Channel.all => list,
    Channel.online => list.where((p) => p.channels.hasOnline).toList(),
    Channel.offline => list.where((p) => p.channels.hasOffline).toList(),
  };

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
