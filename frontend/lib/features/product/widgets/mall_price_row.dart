import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/channel_badge/channel_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/sales.dart';

/// 몰별 가격: 상품가 + 배송비 = 총액, 수집 출처와 시각. 품절은 맨 아래 회색, 버튼 막음.
class MallPriceRow extends StatelessWidget {
  const MallPriceRow({super.key, required this.offer, required this.isBest, required this.onBuy});

  final MallOffer offer;
  final bool isBest;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final sub = o.soldOut
        ? '${o.source} · ${o.checkedLabel}'
        : '${won(o.price)}${o.shipping == 0 ? ' · 무료배송' : ' + 배송 ${won(o.shipping)}'} · ${o.source} · ${o.checkedLabel}';
    final c = o.soldOut ? AppColors.sub : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.mall, style: AppText.bodyStrong.copyWith(color: c)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.tiny),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                o.soldOut ? '—' : won(o.total),
                style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: c),
              ),
              if (isBest) ...[const SizedBox(height: 3), const Pill('최저', fg: AppColors.orange, bg: AppColors.orangeBg, size: 10)],
            ],
          ),
          const SizedBox(width: 12),
          AppButton(o.soldOut ? '품절' : '구매하러 가기', expand: false, height: 34, fontSize: 12, onPressed: o.soldOut ? null : onBuy),
        ],
      ),
    );
  }
}
