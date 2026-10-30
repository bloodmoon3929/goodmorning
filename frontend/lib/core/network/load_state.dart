import 'package:flutter/foundation.dart';

/// 컴포넌트 하나의 데이터 상태. 화면은 조각마다 이 상태를 따로 가진다 (부분 로딩).
sealed class Load<T> {
  const Load();

  T? get valueOrNull => switch (this) {
    Loaded<T>(:final value) => value,
    _ => null,
  };
  bool get isLoading => this is Loading<T>;
}

final class Loading<T> extends Load<T> {
  const Loading();
}

final class Loaded<T> extends Load<T> {
  const Loaded(this.value);
  final T value;
}

final class LoadFailed<T> extends Load<T> {
  const LoadFailed(this.error);
  final Object error;
}

/// 화면 view model의 바탕. 요청 · 로딩 · 오류 상태와 버튼 동작을 맡고, 화면 위젯은 그리기만 한다.
abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;

  /// [fetch]를 부르고 결과를 [assign]으로 넘긴다. 데이터가 오는 동안은 Loading.
  Future<void> load<T>(Future<T> Function() fetch, void Function(Load<T>) assign) async {
    assign(Loading<T>());
    notify();
    try {
      final value = await fetch();
      if (_disposed) return;
      assign(Loaded<T>(value));
    } catch (e) {
      if (_disposed) return;
      assign(LoadFailed<T>(e));
    }
    notify();
  }

  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
