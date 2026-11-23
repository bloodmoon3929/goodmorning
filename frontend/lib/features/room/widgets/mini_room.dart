import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../room_view_model.dart';

/// 방 그림 위에 벽지 · 바닥 · 선반 색을 곱하기로 입히고, 칸에 3D 에셋을 놓는다 (시안의 내 방 꾸미기).
/// 놓은 굿즈는 좌우로 끌면 돌아가고, 누르면 상품 정보가 열린다.
class MiniRoom extends StatelessWidget {
  const MiniRoom({super.key, required this.vm, required this.assetPath, required this.dragging});

  final RoomViewModel vm;
  final String Function(int turn) assetPath;
  final bool dragging; // 트레이에서 끄는 중이면 빈 칸을 보여 준다

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 2,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  foregroundPainter: _TintPainter(wall: vm.wall.color, floor: vm.floor.color, shelf: vm.shelf.color),
                  child: Image.asset('assets/room/room.jpg', fit: BoxFit.fill),
                ),
              ),
              for (var i = 0; i < RoomViewModel.slots.length; i++) _slot(context, i, RoomViewModel.slots[i], w, h),
            ],
          );
        },
      ),
    ),
  );

  Widget _slot(BuildContext context, int i, RoomSlot s, double w, double h) {
    final filled = vm.placed == i;
    return Positioned(
      left: w * s.left / 100,
      top: h * s.top / 100,
      width: w * s.width / 100,
      height: h * s.height / 100,
      child: DragTarget<String>(
        onAcceptWithDetails: (_) => vm.place(i),
        builder: (context, candidate, _) {
          final hot = candidate.isNotEmpty;
          if (filled) {
            return Semantics(
              button: true,
              label: '${s.name}에 놓은 굿즈. 누르면 상품 정보, 좌우로 끌면 회전',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: vm.toggleInfo,
                onHorizontalDragUpdate: (d) => vm.rotateBy(d.delta.dx * 3),
                // 렌더 그림에 여백이 있어서 칸보다 크게, 바닥에 붙여서
                child: OverflowBox(
                  maxWidth: w * s.width / 100 * 2.4,
                  maxHeight: h * s.height / 100 * 2.4,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(assetPath(vm.turn), fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            );
          }
          final show = dragging || hot || vm.placed == null;
          return Semantics(
            button: true,
            label: '${s.name}에 놓기',
            child: GestureDetector(
              onTap: () => vm.place(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: hot ? AppColors.mint.withValues(alpha: 0.35) : (show ? const Color(0x2CF4FFF1) : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                  border: show ? Border.all(color: hot ? AppColors.mint : const Color(0xFFFFFCE8), width: hot ? 2 : 1) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 시안과 같은 영역(방 그림 기준 %)에 색을 곱하기로 입힌다
class _TintPainter extends CustomPainter {
  _TintPainter({this.wall, this.floor, this.shelf});

  final int? wall, floor, shelf;

  Path _poly(Size s, List<(double, double)> pts) {
    final p = Path()..moveTo(s.width * pts.first.$1 / 100, s.height * pts.first.$2 / 100);
    for (final (x, y) in pts.skip(1)) {
      p.lineTo(s.width * x / 100, s.height * y / 100);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    void fill(Path path, int color) => canvas.drawPath(
      path,
      Paint()
        ..color = Color(color)
        ..blendMode = BlendMode.multiply,
    );
    if (wall != null) fill(_poly(size, [(18, 19), (51, 5), (83, 18), (83, 72), (19, 70)]), wall!);
    if (floor != null) {
      // 바닥: 위 70% · 좌우 10% · 아래 6% 안쪽 사다리꼴
      const l = 10.0, r = 90.0, t = 70.0, b = 94.0;
      fill(_poly(size, [(l + (r - l) * .14, t), (l + (r - l) * .84, t), (r, b), (l, b)]), floor!);
    }
    if (shelf != null) fill(Path()..addRect(Rect.fromLTWH(size.width * .64, size.height * .40, size.width * .15, size.height * .17)), shelf!);
  }

  @override
  bool shouldRepaint(_TintPainter old) => old.wall != wall || old.floor != floor || old.shelf != shelf;
}
