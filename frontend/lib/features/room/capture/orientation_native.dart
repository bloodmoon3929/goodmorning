import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'orientation_source.dart';

OrientationSource createPlatformOrientationSource() => _NativeOrientation();

/// 앱(안드로이드 · iOS): 가속도(중력)로 숙인 각도, 자이로를 중력 축으로 적분해 수평 회전
class _NativeOrientation implements OrientationSource {
  final _controller = StreamController<DeviceAngles>.broadcast();
  final _subs = <StreamSubscription<Object>>[];
  List<double> _gravity = const [0, 9.8, 0];
  double _heading = 0;
  DateTime? _last;

  @override
  Stream<DeviceAngles> get angles => _controller.stream;

  @override
  Future<bool> start() async {
    try {
      _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) => _gravity = [e.x, e.y, e.z]));
      _subs.add(
        gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
          final now = DateTime.now();
          final g = _gravity;
          final n = math.sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
          if (_last != null && n > 0) {
            final dt = now.difference(_last!).inMicroseconds / 1e6;
            final vertical = (e.x * g[0] + e.y * g[1] + e.z * g[2]) / n; // 중력 축 둘레 회전 (rad/s)
            _heading += vertical * dt * 180 / math.pi;
          }
          _last = now;
          final down = n > 0 ? math.asin((g[2] / n).clamp(-1.0, 1.0)) * 180 / math.pi : 0.0;
          _controller.add((downDeg: down, headingDeg: _heading));
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _controller.close();
  }
}
