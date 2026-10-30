import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/sales.dart';

/// 지도 자리 (프로토타입). 실제 지도 SDK 대신 길 · 강 · 공원을 그리고, 매장 마커를 재고 상태 색으로 찍는다.
/// 마커 색 = 재고 상태, 내 위치 = 파란 점, 고른 마커 = 주황 테두리.
class FakeMap extends StatelessWidget {
  const FakeMap({super.key, required this.stores, required this.selectedId, required this.onSelect});

  final List<StoreSummary> stores;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return GestureDetector(
        onTap: () => onSelect(null),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            // 내 위치
            Positioned(
              left: w * 0.36 - 20,
              top: h * 0.52 - 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.18), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 3),
                  ),
                ),
              ),
            ),
            for (final s in stores) _marker(s, w, h),
          ],
        ),
      );
    },
  );

  Widget _marker(StoreSummary s, double w, double h) {
    final selected = s.store.id == selectedId;
    final color = switch (s.markerStatus) {
      StockStatus.many => AppColors.green,
      StockStatus.few => const Color(0xFFE3B341),
      _ => const Color(0xFFB0B5BD),
    };
    return Positioned(
      left: w * s.store.mapX - 22,
      top: h * s.store.mapY - 22,
      child: Semantics(
        button: true,
        label: '${s.store.name} · ${stockLabel(s)}',
        child: GestureDetector(
          onTap: () => onSelect(s.store.id),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange, width: 3),
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2.5),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                if (s.store.isPopup)
                  Positioned(
                    top: -22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text('팝업', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String stockLabel(StoreSummary s) => s.myIpStock > 0 ? '내 IP 굿즈 재고 ${s.myIpStock}개' : '재고 확인 필요';
}

/// 범례: 마커 색 = 재고 상태
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (s, c) in [
          (StockStatus.many, AppColors.green),
          (StockStatus.few, const Color(0xFFE3B341)),
          (StockStatus.check, const Color(0xFFB0B5BD)),
        ]) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            s.short,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
          const SizedBox(width: 10),
        ],
      ],
    ),
  );
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEEF1E8));
    // 공원
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.64, h * 0.30, w * 0.26, h * 0.18), const Radius.circular(12)),
      Paint()..color = const Color(0xFFDCEBCF),
    );
    // 강
    final river = Path()
      ..moveTo(0, h * 0.58)
      ..cubicTo(w * 0.3, h * 0.52, w * 0.6, h * 0.66, w, h * 0.56)
      ..lineTo(w, h * 0.64)
      ..cubicTo(w * 0.6, h * 0.74, w * 0.3, h * 0.60, 0, h * 0.66)
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0xFFCFE3F5));
    // 길
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 11;
    for (final x in [0.18, 0.44, 0.75]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), road);
    }
    for (final y in [0.22, 0.42, 0.80]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), road);
    }
    canvas.drawLine(Offset(0, h * 0.95), Offset(w, h * 0.70), road..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}
