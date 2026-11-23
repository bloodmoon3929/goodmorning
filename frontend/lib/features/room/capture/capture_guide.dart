/// 자동 촬영 가이드의 판단 (카메라 · 센서와 떼어 놓아 테스트할 수 있게).
///
/// 가우시안 스플래팅에 좋은 촬영: 굿즈는 받침 위에 두고(손에 들지 않음) 휴대폰을 들고 둘레를 돈다.
/// 높이 3줄(낮게 · 중간 · 높게) × 방향 24칸(15°) = 72장. 얼굴 등록처럼 칸이 채워지고,
/// 아직 안 찍은 칸에서 휴대폰이 멈추면(흔들림 없음) 자동으로 찍는다.
library;

/// 높이 한 줄: 카메라가 아래를 내려다보는 각도 범위(도)
class CaptureRing {
  const CaptureRing(this.label, this.minDown, this.maxDown);
  final String label;
  final double minDown, maxDown;
  double get target => (minDown + maxDown) / 2;
}

/// 찍을 칸 (줄 · 방향)
typedef CaptureCell = ({int ring, int sector});

enum GuideHint { start, tiltDown, tiltUp, moveOn, slowDown, hold, ringDone, allDone }

class CaptureGuide {
  CaptureGuide({this.sectors = 24, this.holdMs = 300, this.maxSpeed = 25});

  static const rings = [CaptureRing('낮게', -5, 20), CaptureRing('중간', 20, 45), CaptureRing('높게', 45, 75)];

  final int sectors;
  final int holdMs; // 이만큼 멈춰 있어야 찍는다
  final double maxSpeed; // 도/초. 이보다 빠르면 흔들린 사진이 된다
  final Set<CaptureCell> done = {};

  double? _heading0;
  double? _lastHeading, _lastDown;
  int? _lastMs, _stableSince;
  int? currentRing;
  int? currentSector;
  double speed = 0;
  GuideHint hint = GuideHint.start;

  int get total => rings.length * sectors;
  int countIn(int ring) => done.where((c) => c.ring == ring).length;
  bool get finished => done.length >= total;

  /// 한 줄을 다 찍기 전에는 그 줄을 권한다 (아래 줄부터)
  int get suggestedRing {
    for (var r = 0; r < rings.length; r++) {
      if (countIn(r) < sectors) return r;
    }
    return rings.length - 1;
  }

  static double _wrap(double d) => ((d % 360) + 360) % 360;

  /// 센서 값 한 번 → 지금 찍을 칸이면 돌려준다 (찍은 뒤 [markDone]).
  /// [downDeg] 카메라가 아래를 보는 각도, [headingDeg] 수평 방향(아무 기준, 처음 값이 0°)
  CaptureCell? update({required double downDeg, required double headingDeg, required int nowMs}) {
    _heading0 ??= headingDeg;
    if (_lastMs != null && nowMs > _lastMs!) {
      final dt = (nowMs - _lastMs!) / 1000;
      var dh = (headingDeg - _lastHeading!).abs() % 360;
      if (dh > 180) dh = 360 - dh;
      final dd = (downDeg - _lastDown!).abs();
      // 순간값이 튀지 않게 조금 부드럽게
      speed = speed * 0.6 + ((dh + dd) / dt) * 0.4;
    }
    _lastMs = nowMs;
    _lastHeading = headingDeg;
    _lastDown = downDeg;

    final rel = _wrap(headingDeg - _heading0!);
    currentSector = (rel / (360 / sectors)).floor() % sectors;
    final ringIndex = rings.indexWhere((r) => downDeg >= r.minDown && downDeg < r.maxDown);
    currentRing = ringIndex < 0 ? null : ringIndex;

    if (finished) {
      hint = GuideHint.allDone;
      return null;
    }
    if (currentRing == null) {
      hint = downDeg < rings.first.minDown ? GuideHint.tiltDown : GuideHint.tiltUp;
      _stableSince = null;
      return null;
    }
    final cell = (ring: currentRing!, sector: currentSector!);
    if (done.contains(cell)) {
      hint = countIn(currentRing!) >= sectors ? GuideHint.ringDone : GuideHint.moveOn;
      _stableSince = null;
      return null;
    }
    if (speed > maxSpeed) {
      hint = GuideHint.slowDown;
      _stableSince = null;
      return null;
    }
    _stableSince ??= nowMs;
    hint = GuideHint.hold;
    if (nowMs - _stableSince! >= holdMs) {
      _stableSince = null;
      return cell;
    }
    return null;
  }

  void markDone(CaptureCell cell) => done.add(cell);

  void reset() {
    done.clear();
    _heading0 = _lastHeading = _lastDown = null;
    _lastMs = _stableSince = null;
    currentRing = currentSector = null;
    speed = 0;
    hint = GuideHint.start;
  }

  String hintText() {
    final want = rings[suggestedRing];
    return switch (hint) {
      GuideHint.start => '굿즈를 받침 위에 두고, 원 안에 꽉 차게 맞춘 뒤 둘레를 천천히 돌아 주세요',
      GuideHint.tiltDown => '휴대폰을 조금 더 숙여 주세요 (${want.label}: ${want.target.round()}° 아래로)',
      GuideHint.tiltUp => '휴대폰을 조금 세워 주세요 (${want.label}: ${want.target.round()}° 아래로)',
      GuideHint.moveOn => '찍은 칸이에요. 같은 거리로 천천히 옆으로 걸어가세요',
      GuideHint.slowDown => '조금 천천히 — 멈추면 자동으로 찍혀요',
      GuideHint.hold => '그대로 멈춰 주세요…',
      GuideHint.ringDone => '${rings[currentRing ?? 0].label} 줄 끝! ${want.label} 높이로 바꿔서 한 바퀴 더',
      GuideHint.allDone => '다 찍었어요. [사진 받기]로 내려받아 3D로 만드세요',
    };
  }
}
