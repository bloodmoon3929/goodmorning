import 'package:flutter/material.dart';

import '../../../components/bottom_sheet/app_bottom_sheet.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/ip_tile/ip_tile.dart';
import '../../../components/stock_badge/stock_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/catalog.dart';
import '../../../models/sales.dart';

/// 20. 재고 제보 창: 매장 · 굿즈(버전) · 지금 재고 · 사진(선택). 보내면 true.
Future<bool?> showStockReportSheet(
  BuildContext context, {
  required StoreDetail detail,
  StoreStockItem? initial,
  required Future<void> Function(Product p, Variant v, StockStatus status) onSend,
}) => showAppBottomSheet<bool>(
  context,
  title: '재고 제보',
  builder: (_) => _StockReportForm(detail: detail, initial: initial ?? detail.items.firstOrNull, onSend: onSend),
);

class _StockReportForm extends StatefulWidget {
  const _StockReportForm({required this.detail, required this.initial, required this.onSend});

  final StoreDetail detail;
  final StoreStockItem? initial;
  final Future<void> Function(Product p, Variant v, StockStatus status) onSend;

  @override
  State<_StockReportForm> createState() => _StockReportFormState();
}

class _StockReportFormState extends State<_StockReportForm> {
  late StoreStockItem? item = widget.initial;
  StockStatus? status;
  bool photo = false;
  bool sending = false;

  Future<void> _send() async {
    setState(() => sending = true);
    await widget.onSend(item!.product, item!.variant, status!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.detail.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('매장', Text(widget.detail.store.name, style: AppText.label)),
        const SizedBox(height: 10),
        _field(
          '굿즈',
          items.isEmpty
              ? Text('등록된 굿즈가 없어요', style: AppText.caption)
              : DropdownButtonHideUnderline(
                  child: DropdownButton<StoreStockItem>(
                    value: item,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    style: AppText.label,
                    items: [
                      for (final it in items)
                        DropdownMenuItem(
                          value: it,
                          child: Text('${it.product.name} · ${it.variant.label}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => item = v),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        const Text('지금 재고', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final s in [StockStatus.many, StockStatus.few, StockStatus.none]) ...[
              if (s != StockStatus.many) const SizedBox(width: 10),
              Expanded(child: _statusButton(s)),
            ],
          ],
        ),
        const SizedBox(height: 18),
        const Text('사진 (선택)', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => photo = !photo),
          child: SizedBox(
            width: 72,
            height: 72,
            child: photo
                ? Container(
                    decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(
                      '사진 1장',
                      style: AppText.caption.copyWith(color: AppColors.green, fontWeight: FontWeight.w600),
                    ),
                  )
                : CustomPaint(
                    painter: DashedRRectPainter(color: AppColors.dashed, radius: 12),
                    child: Center(child: Text('+ 사진', style: AppText.caption)),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Text('사장님이 확인하면 반영돼요. 사장님이 없는 매장은 같은 제보가 2건 모이면 반영돼요.', style: AppText.caption),
        const SizedBox(height: 16),
        AppButton('제보하기', busy: sending, onPressed: item != null && status != null ? _send : null),
      ],
    );
  }

  Widget _field(String label, Widget child) => Row(
    children: [
      SizedBox(
        width: 44,
        child: Text(label, style: AppText.label.copyWith(color: AppColors.sub)),
      ),
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
          child: child,
        ),
      ),
    ],
  );

  Widget _statusButton(StockStatus s) {
    final on = status == s;
    final (fg, bg) = stockColors(s);
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? bg : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? fg : AppColors.line, width: on ? 2 : 1),
        ),
        child: InkWell(
          onTap: () => setState(() => status = s),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                s.short,
                style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? fg : AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
