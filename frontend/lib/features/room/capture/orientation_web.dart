import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'orientation_source.dart';

OrientationSource createPlatformOrientationSource() => _WebOrientation();

/// 브라우저 DeviceOrientationEvent: beta = 앞뒤 기울기(세우면 90°, 눕히면 0°), alpha = 수평 회전
class _WebOrientation implements OrientationSource {
  final _controller = StreamController<DeviceAngles>.broadcast();
  JSFunction? _listener;

  @override
  Stream<DeviceAngles> get angles => _controller.stream;

  @override
  Future<bool> start() async {
    // 아이폰(iOS 13+)은 버튼을 누른 순간에 허락을 받아야 한다
    final ctor = globalContext['DeviceOrientationEvent'];
    if (ctor == null) return false;
    final ask = (ctor as JSObject)['requestPermission'];
    if (ask != null) {
      try {
        final result = await (ctor.callMethod<JSPromise<JSString>>('requestPermission'.toJS)).toDart;
        if (result.toDart != 'granted') return false;
      } catch (_) {
        return false;
      }
    }
    final got = Completer<bool>();
    void onEvent(web.DeviceOrientationEvent e) {
      final beta = e.beta, alpha = e.alpha;
      if (beta == null || alpha == null) return;
      if (!got.isCompleted) got.complete(true);
      _controller.add((downDeg: 90 - beta.toDouble(), headingDeg: alpha.toDouble()));
    }

    _listener = onEvent.toJS;
    web.window.addEventListener('deviceorientation', _listener);
    // 센서가 없는 기기(데스크톱)는 값이 오지 않는다
    return got.future.timeout(const Duration(milliseconds: 1500), onTimeout: () => false);
  }

  @override
  void dispose() {
    if (_listener != null) web.window.removeEventListener('deviceorientation', _listener);
    _controller.close();
  }
}
