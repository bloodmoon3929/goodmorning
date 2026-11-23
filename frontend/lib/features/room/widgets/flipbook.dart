import 'package:flutter/material.dart';

/// 그림 여러 장을 차례로 넘겨 영상처럼 보여 준다 (촬영 프레임 · 분할 결과).
/// [playing]이 true가 되면 처음부터 [duration] 동안 재생하고 [onDone]을 부른다.
class Flipbook extends StatefulWidget {
  const Flipbook({super.key, required this.count, required this.path, required this.playing, required this.duration, this.onProgress, this.onDone});

  final int count;
  final String Function(int i) path;
  final bool playing;
  final Duration duration;
  final ValueChanged<double>? onProgress;
  final VoidCallback? onDone;

  @override
  State<Flipbook> createState() => _FlipbookState();
}

class _FlipbookState extends State<Flipbook> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..addListener(() => widget.onProgress?.call(_c.value))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });

  // 재생 시작은 그리기가 끝난 뒤에 (진행률 콜백이 부모 setState를 부르므로 build 중에 부르면 안 된다)
  void _playAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.playing) _c.forward(from: 0);
  });

  @override
  void initState() {
    super.initState();
    if (widget.playing) _playAfterFrame();
  }

  @override
  void didUpdateWidget(Flipbook old) {
    super.didUpdateWidget(old);
    _c.duration = widget.duration;
    if (widget.playing && !old.playing) _playAfterFrame();
    if (!widget.playing && old.playing) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final i = (_c.value * (widget.count - 1)).round();
      return Image.asset(widget.path(i), fit: BoxFit.cover, gaplessPlayback: true, width: double.infinity, height: double.infinity);
    },
  );
}
