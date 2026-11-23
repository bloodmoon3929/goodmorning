import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/chips/app_chip.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'turntable.dart';

/// 방에 놓은 굿즈를 눌렀을 때: 360° 돌려 보며 어느 방향으로 전시할지 정한다.
/// 돌리는 동안 뒤의 방에도 바로 보이고, [취소]하면 원래 방향으로 돌아간다.
class OrientationSheet extends StatefulWidget {
  const OrientationSheet({super.key, required this.count, required this.initial, required this.path, required this.onPreview, required this.onInfo});

  final int count; // 회전 렌더 장 수 (72장 = 5°씩)
  final int initial;
  final String Function(int turn) path;
  final ValueChanged<int> onPreview; // 돌리는 동안 방에 미리 보이기
  final VoidCallback onInfo;

  /// 정한 회전 번호를 돌려준다. 닫거나 취소하면 null
  static Future<int?> show(
    BuildContext context, {
    required int count,
    required int initial,
    required String Function(int turn) path,
    required ValueChanged<int> onPreview,
    required VoidCallback onInfo,
  }) => showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => OrientationSheet(count: count, initial: initial, path: path, onPreview: onPreview, onInfo: onInfo),
  );

  static const quick = [(0, '정면'), (90, '옆'), (180, '뒤'), (270, '반대쪽 옆')];

  @override
  State<OrientationSheet> createState() => _OrientationSheetState();
}

class _OrientationSheetState extends State<OrientationSheet> {
  late int turn = widget.initial;

  int get degrees => (turn * 360 / widget.count).round() % 360;

  void _set(int t) {
    setState(() => turn = t % widget.count);
    widget.onPreview(turn);
  }

  void _setDegrees(double deg) => _set((((deg % 360) + 360) % 360 / 360 * widget.count).round());

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('전시 방향 정하기', style: AppText.title),
          const SizedBox(height: 2),
          Text('인형을 좌우로 끌거나 원을 돌려 방에서 보일 방향을 고르세요.', style: AppText.caption),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: Row(
              children: [
                Expanded(
                  child: Turntable(count: widget.count, index: turn, path: widget.path, onRotate: (dx) => _set(turn - (dx / 6).round()), onSetIndex: _set),
                ),
                const SizedBox(width: 8),
                AngleDial(degrees: degrees.toDouble(), onChanged: _setDegrees),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: '빠른 방향',
            child: ChipRow(
              padding: EdgeInsets.zero,
              children: [
                for (final (deg, name) in OrientationSheet.quick)
                  AppChip('$name $deg°', size: 12, style: ChipStyle.point, selected: degrees == deg, onTap: () => _setDegrees(deg.toDouble())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton('이 방향으로 전시 ($degrees°)', onPressed: () => Navigator.of(context).pop(turn)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton('취소', kind: AppButtonKind.secondary, height: 44, fontSize: 14, onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  '상품 정보',
                  kind: AppButtonKind.secondary,
                  height: 44,
                  fontSize: 14,
                  onPressed: () {
                    Navigator.of(context).pop(turn);
                    widget.onInfo();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 360° 다이얼: 원 위의 손잡이를 끌어 각도를 정한다 (위 = 0°, 시계 방향)
class AngleDial extends StatelessWidget {
  const AngleDial({super.key, required this.degrees, required this.onChanged, this.size = 150});

  final double degrees;
  final ValueChanged<double> onChanged;
  final double size;

  void _fromPosition(Offset p) {
    final c = Offset(size / 2, size / 2);
    final v = p - c;
    if (v.distance < 8) return;
    onChanged((math.atan2(v.dx, -v.dy) * 180 / math.pi + 360) % 360);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '전시 방향 다이얼',
    value: '${degrees.round()}°',
    increasedValue: '${(degrees.round() + 15) % 360}°',
    decreasedValue: '${(degrees.round() + 345) % 360}°',
    onIncrease: () => onChanged(degrees + 15),
    onDecrease: () => onChanged(degrees - 15),
    child: GestureDetector(
      onPanDown: (d) => _fromPosition(d.localPosition),
      onPanUpdate: (d) => _fromPosition(d.localPosition),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DialPainter(degrees),
          child: Center(
            child: Text('${degrees.round()}°', style: AppText.title.copyWith(color: AppColors.primary)),
          ),
        ),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.degrees);
  final double degrees;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.cardLine,
    );
    // 0°부터 지금 각도까지 민트 호
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      degrees / 180 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mint,
    );
    // 45°마다 눈금
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + d * (r - 14),
        c + d * (r - (i.isEven ? 22 : 18)),
        Paint()
          ..strokeWidth = 2
          ..color = AppColors.sub,
      );
    }
    final a = -math.pi / 2 + degrees / 180 * math.pi;
    final knob = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(knob, 11, Paint()..color = AppColors.primary);
    canvas.drawCircle(knob, 5, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.degrees != degrees;
}
