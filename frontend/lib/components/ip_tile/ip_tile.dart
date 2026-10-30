import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../goods_thumb/goods_thumb.dart';

/// 홈의 내 IP: 작은 사각 타일 + 이름
class IpTileSmall extends StatelessWidget {
  const IpTileSmall({super.key, required this.ip, required this.onTap});

  final Ip ip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: 70,
      child: Column(
        children: [
          GoodsThumb(emoji: ip.emoji, bg: ip.bg, size: 58, radius: 16, emojiScale: 0.6),
          const SizedBox(height: 6),
          Text(ip.tileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label.copyWith(fontSize: 12)),
        ],
      ),
    ),
  );
}

/// 홈의 [+ 추가] 타일 (점선)
class AddTileSmall extends StatelessWidget {
  const AddTileSmall({super.key, required this.onTap, this.label = '추가'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: 70,
      child: Column(
        children: [
          CustomPaint(
            painter: DashedRRectPainter(radius: 16),
            child: const SizedBox(width: 58, height: 58, child: Icon(Icons.add_rounded, color: AppColors.sub, size: 26)),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppText.caption),
        ],
      ),
    ),
  );
}

/// 회원가입 IP 고르기 · IP 목록 조정 · 굿즈 탐색의 큰 IP 타일.
/// 고르면 주황 테두리와 ✓.
class IpTileGrid extends StatelessWidget {
  const IpTileGrid({super.key, required this.ip, required this.onTap, this.selected = false, this.sub, this.showCheck = true});

  final Ip ip;
  final VoidCallback onTap;
  final bool selected;
  final String? sub; // 캐릭터 4 · 굿즈 128
  final bool showCheck;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.orange : AppColors.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  GoodsThumb(emoji: ip.emoji, bg: ip.bg, width: double.infinity, height: 66, radius: 10, emojiScale: 0.62),
                  const SizedBox(height: 6),
                  Text(ip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
                  if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny.copyWith(fontSize: 10)),
                  const SizedBox(height: 2),
                ],
              ),
            ),
            if (selected && showCheck)
              const Positioned(
                right: 8,
                top: 8,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.orange,
                  child: Icon(Icons.check_rounded, size: 13, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 점선 둥근 사각형 (추가 · 요청 자리)
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({this.radius = 12, this.color = AppColors.dashed, this.dash = 5, this.gap = 4, this.strokeWidth = 1.4});

  final double radius;
  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(strokeWidth / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) => old.color != color || old.radius != radius;
}
