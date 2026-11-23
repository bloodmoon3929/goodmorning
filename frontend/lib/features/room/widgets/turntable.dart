import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 3D 에셋 미리보기: 한 바퀴 돌려 가며 렌더링한 그림을 손가락으로 끌어 돌린다.
/// [autoSpin]이면 손대기 전까지 천천히 돈다.
class Turntable extends StatefulWidget {
  const Turntable({
    super.key,
    required this.count,
    required this.index,
    required this.path,
    required this.onRotate,
    required this.onSetIndex,
    this.autoSpin = false,
  });

  final int count;
  final int index;
  final String Function(int i) path;
  final ValueChanged<double> onRotate;
  final ValueChanged<int> onSetIndex;
  final bool autoSpin;

  @override
  State<Turntable> createState() => _TurntableState();
}

class _TurntableState extends State<Turntable> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _touched = false;
  double _drag = 0;

  void _syncSpin() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final spin = widget.autoSpin && !_touched && !reduce;
    if (spin && !_ticker.isActive) _ticker.start();
    if (!spin && _ticker.isActive) _ticker.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  void _tick(Duration t) {
    // 한 장에 70ms → 72장이면 5초에 한 바퀴
    if (t - _last < const Duration(milliseconds: 70)) return;
    _last = t;
    widget.onSetIndex(widget.index + 1);
  }

  void _stopSpin() {
    _touched = true;
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void didUpdateWidget(Turntable old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '3D 미리보기. 좌우로 끌어서 돌려 보세요',
    image: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _stopSpin();
        _drag = 0;
      },
      onHorizontalDragUpdate: (d) {
        _drag += d.delta.dx;
        if (_drag.abs() >= 6) {
          widget.onRotate(_drag);
          _drag = 0;
        }
      },
      child: Image.asset(widget.path(widget.index), fit: BoxFit.contain, gaplessPlayback: true, width: double.infinity, height: double.infinity),
    ),
  );
}
