import '../../app/app_state.dart';
import '../../core/network/load_state.dart';
import '../../models/account.dart';

/// 9. 알림 목록
class NotificationViewModel extends ViewModel {
  NotificationViewModel(this.state) {
    reload();
  }

  final AppState state;
  Load<List<NotificationItem>> items = const Loading();
  String filter = '전체';

  static const filters = ['전체', '가격', '재입고', '입고', '제보 · 문의'];

  void reload() => load(state.api.notifications, (v) => items = v);

  void setFilter(String f) {
    filter = f;
    notify();
  }

  List<NotificationItem> visible(List<NotificationItem> all) => filter == '전체' ? all : all.where((n) => n.type.group == filter).toList();
}
