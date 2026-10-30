import '../../core/network/goodmorning_api.dart';
import '../../core/network/load_state.dart';
import '../../models/account.dart';

/// 11. 사진 검색 결과 — 올린 사진으로 같은 굿즈와 다른 버전을 찾고, 글자 조건을 더해 다시 찾는다
class PhotoSearchViewModel extends ViewModel {
  PhotoSearchViewModel(this.api, this.photoId) {
    run();
  }

  final GoodmorningApi api;
  String photoId;
  String condition = '';
  Load<PhotoSearchResult> result = const Loading();

  void run() => load(() => api.photoSearch(photoId, condition: condition), (v) => result = v);

  void retake(String id) {
    photoId = id;
    condition = '';
    run();
  }

  void addCondition(String text) {
    condition = text.trim();
    run();
  }

  /// 같은 굿즈의 다른 버전 묶음 (점선 안). 위쪽 결과 중 같은 상품이 2개 이상이면 묶는다.
  static List<List<PhotoMatch>> group(List<PhotoMatch> matches) {
    final groups = <List<PhotoMatch>>[];
    for (final m in matches) {
      if (groups.isNotEmpty && groups.last.first.groupId == m.groupId) {
        groups.last.add(m);
      } else {
        groups.add([m]);
      }
    }
    return groups;
  }
}
