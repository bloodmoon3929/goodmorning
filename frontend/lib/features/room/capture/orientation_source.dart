import 'orientation_native.dart' if (dart.library.js_interop) 'orientation_web.dart' as platform;

/// 휴대폰 기울기 한 번: 카메라가 아래를 보는 각도(도), 수평 방향(도, 기준은 아무 데나)
typedef DeviceAngles = ({double downDeg, double headingDeg});

/// 휴대폰 기울기 센서. 웹은 DeviceOrientationEvent(아이폰은 버튼을 누를 때 허락을 받는다), 앱은 sensors_plus.
abstract class OrientationSource {
  Stream<DeviceAngles> get angles;

  /// 센서를 켠다. 허락을 못 받았거나 센서가 없으면 false (예: 데스크톱 브라우저)
  Future<bool> start();

  void dispose();
}

OrientationSource createOrientationSource() => platform.createPlatformOrientationSource();
