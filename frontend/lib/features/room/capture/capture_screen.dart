import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../components/buttons/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'capture_guide.dart';
import 'download.dart';
import 'orientation_source.dart';

/// 찍은 사진 한 장 + 찍을 때의 각도 (3D 복원 때 참고)
class Shot {
  Shot(this.cell, this.downDeg, this.headingDeg, this.bytes);
  final CaptureCell cell;
  final double downDeg, headingDeg;
  final List<int>? bytes; // 카메라가 없으면 null (시연 모드)
  String get name => 'r${cell.ring}_s${cell.sector.toString().padLeft(2, '0')}.jpg';
}

/// 자동 촬영 가이드 — 굿즈 둘레를 돌면 정해진 높이 · 방향마다 멈출 때 자동으로 찍는다 (얼굴 등록처럼).
/// 다 찍으면 사진 묶음(zip)을 내려받아 PC의 3D 파이프라인(backend/ai/asset3d)에 넣는다.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with SingleTickerProviderStateMixin {
  final guide = CaptureGuide();
  final shots = <Shot>[];
  CameraController? _camera;
  OrientationSource? _sensor;
  StreamSubscription<DeviceAngles>? _sub;
  late final Ticker _ticker = createTicker((_) => _feedSimulated());
  bool _started = false, _busy = false, _simulated = false, _flash = false;
  String? _cameraNote;
  DeviceAngles _sim = (downDeg: 10, headingDeg: 0);
  DeviceAngles? _now;

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    _sensor?.dispose();
    _camera?.dispose();
    super.dispose();
  }

  /// 버튼을 눌러 시작: 카메라 · 기울기 센서 허락을 받는다 (아이폰은 누른 순간에만 물을 수 있다)
  Future<void> _start() async {
    setState(() => _started = true);
    final sensor = createOrientationSource();
    final ok = await sensor.start();
    if (!mounted) return;
    if (ok) {
      _sensor = sensor;
      _sub = sensor.angles.listen(_onAngles);
    } else {
      sensor.dispose();
      _simulated = true; // 센서가 없으면 화면을 끌어서 각도를 흉내 낸다 (데스크톱 시연)
      _ticker.start();
    }
    try {
      final cams = await availableCameras();
      final back = cams.where((c) => c.lensDirection == CameraLensDirection.back).firstOrNull ?? cams.firstOrNull;
      if (back == null) throw CameraException('none', '카메라가 없어요');
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camera = c);
    } catch (e) {
      if (mounted) setState(() => _cameraNote = '카메라를 쓸 수 없어요 ($e). 각도 안내만 시연합니다.');
    }
  }

  void _feedSimulated() => _onAngles(_sim);

  void _onAngles(DeviceAngles a) {
    _now = a;
    final cell = guide.update(downDeg: a.downDeg, headingDeg: a.headingDeg, nowMs: DateTime.now().millisecondsSinceEpoch);
    if (cell != null && !_busy) _take(cell, a);
    if (mounted) setState(() {});
  }

  Future<void> _take(CaptureCell cell, DeviceAngles a) async {
    _busy = true;
    try {
      List<int>? bytes;
      final c = _camera;
      if (c != null && c.value.isInitialized && !c.value.isTakingPicture) {
        bytes = await (await c.takePicture()).readAsBytes();
      }
      guide.markDone(cell);
      shots.add(Shot(cell, a.downDeg, a.headingDeg, bytes));
      setState(() => _flash = true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _flash = false);
    } catch (_) {
      // 찍다 실패하면 그 칸은 비워 두고 다음에 다시
    } finally {
      _busy = false;
    }
  }

  Future<void> _download() async {
    final archive = Archive();
    final meta = <Map<String, Object?>>[];
    for (final s in shots) {
      final b = s.bytes;
      if (b == null) continue;
      archive.addFile(ArchiveFile('capture/${s.name}', b.length, b));
      meta.add({
        'file': s.name,
        'ring': CaptureGuide.rings[s.cell.ring].label,
        'sector': s.cell.sector,
        'down_deg': double.parse(s.downDeg.toStringAsFixed(1)),
        'heading_deg': double.parse(s.headingDeg.toStringAsFixed(1)),
      });
    }
    final json = utf8.encode(const JsonEncoder.withIndent(' ').convert({'guide': '높이 3줄 × 방향 24칸', 'shots': meta}));
    archive.addFile(ArchiveFile('capture/capture.json', json.length, json));
    final zip = ZipEncoder().encode(archive);
    final ok = await saveBytes('goodmorning-capture-${DateTime.now().millisecondsSinceEpoch}.zip', zip);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '사진 ${meta.length}장을 내려받았어요. PC에서 asset3d로 3D를 만드세요' : '이 기기에서는 아직 내려받기를 지원하지 않아요 (웹에서 열어 주세요)')));
  }

  void _restart() => setState(() {
    guide.reset();
    shots.clear();
  });

  @override
  Widget build(BuildContext context) {
    final withImages = shots.where((s) => s.bytes != null).length;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1A2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1A2B),
        foregroundColor: AppColors.white,
        title: Text('자동 촬영 가이드', style: AppText.title.copyWith(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _rings(),
            Expanded(child: _started ? _stage() : _intro()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _started ? guide.hintText() : '굿즈는 손에 들지 말고 받침(무늬 있는 종이 등) 위에 세워 두세요',
                      style: AppText.body.copyWith(color: AppColors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_cameraNote != null || _simulated) ...[
                    const SizedBox(height: 4),
                    Text(
                      [?_cameraNote, if (_simulated) '기울기 센서가 없어 화면을 끌어서 각도를 흉내 냅니다 (시연용, 휴대폰 브라우저에서는 센서로 동작)'].join('\n'),
                      style: AppText.caption.copyWith(color: AppColors.peach),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (!_started)
                    AppButton('촬영 시작 (카메라 · 기울기 센서 허락)', onPressed: _start)
                  else
                    Row(
                      children: [
                        Expanded(child: AppButton('사진 받기 ($withImages장)', onPressed: withImages == 0 ? null : _download)),
                        const SizedBox(width: 8),
                        AppButton('처음부터', kind: AppButtonKind.secondary, expand: false, onPressed: shots.isEmpty ? null : _restart),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('가우시안 스플래팅이 잘 되는 촬영', style: AppText.section.copyWith(color: AppColors.white)),
        const SizedBox(height: 12),
        for (final t in [
          '굿즈를 받침 위에 두고 휴대폰을 들고 둘레를 돕니다 (손에 들면 손이 가리고 모양이 눌려요)',
          '원 안에 굿즈가 꽉 차게 맞추고, 도는 동안 같은 거리를 지킵니다',
          '높이 3줄(낮게 · 중간 · 높게) × 방향 24칸 = 72장. 칸에서 멈추면 자동으로 찍혀요',
          '밝고 고른 빛, 반사가 적은 곳. 흔들리면 찍지 않고 기다립니다',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('·  ', style: TextStyle(color: AppColors.mint)),
                Expanded(
                  child: Text(t, style: AppText.body.copyWith(color: const Color(0xFFD7DEE8))),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _rings() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: [
        for (var r = 0; r < CaptureGuide.rings.length; r++) ...[
          if (r > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: guide.currentRing == r ? AppColors.mint.withValues(alpha: 0.22) : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: guide.suggestedRing == r ? AppColors.mint : Colors.transparent),
              ),
              child: Text(
                '${CaptureGuide.rings[r].label} ${guide.countIn(r)}/${guide.sectors}',
                textAlign: TextAlign.center,
                style: AppText.label.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _stage() {
    final cam = _camera;
    final ring = guide.currentRing ?? guide.suggestedRing;
    return GestureDetector(
      // 시연 모드: 좌우로 끌면 둘레를 도는 것, 위아래로 끌면 숙이는 것
      onPanUpdate: _simulated
          ? (d) => _sim = (downDeg: (_sim.downDeg + d.delta.dy * 0.25).clamp(-20, 85).toDouble(), headingDeg: _sim.headingDeg + d.delta.dx * 0.4)
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cam != null && cam.value.isInitialized)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: 300, height: 300 * cam.value.aspectRatio, child: CameraPreview(cam)),
              ),
            )
          else
            const ColoredBox(color: Color(0xFF15253B)),
          CustomPaint(
            painter: _GuidePainter(
              done: {for (final c in guide.done.where((c) => c.ring == ring)) c.sector},
              current: guide.currentRing == null ? null : guide.currentSector,
              sectors: guide.sectors,
            ),
          ),
          if (_flash) const ColoredBox(color: Color(0x66FFFFFF)),
          Positioned(
            left: 12,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xCC0E1A2B), borderRadius: BorderRadius.circular(10)),
              child: Text(
                _now == null ? '각도 확인 중' : '아래로 ${_now!.downDeg.round()}° · ${guide.done.length}/${guide.total}장',
                style: AppText.label.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 얼굴 등록처럼: 가운데 원(굿즈를 맞출 자리) + 둘레 눈금(찍은 방향은 민트, 지금 방향은 피치)
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.done, required this.current, required this.sectors});

  final Set<int> done;
  final int? current;
  final int sectors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.34;
    final hole = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final shade = Path()..addRect(Offset.zero & size);
    canvas.drawPath(Path.combine(PathOperation.difference, shade, hole), Paint()..color = const Color(0x8C0E1A2B));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xCCFFFFFF),
    );
    for (var i = 0; i < sectors; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / sectors;
      final dir = Offset(math.cos(a), math.sin(a));
      final isDone = done.contains(i), isNow = current == i;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isNow ? 7 : 5
        ..color = isDone ? AppColors.mint : (isNow ? AppColors.peach : const Color(0x66FFFFFF));
      canvas.drawLine(c + dir * (r + 10), c + dir * (r + (isDone || isNow ? 30 : 20)), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.done.length != done.length || old.current != current;
}
