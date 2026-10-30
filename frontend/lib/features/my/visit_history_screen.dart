import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/catalog.dart';
import 'my_view_model.dart';
import 'widgets/issue_sheet.dart';

/// 22. 이동 기록 — 마이 → 이동 기록. [구매하러 가기]를 누른 시점의 몰 · 가격이 남는다.
class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  late final vm = ProductLookupViewModel(AppScope.read(context), AppScope.read(context).visits.map((v) => v.productId).toList());

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('이동 기록')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const InfoBanner('구매하러 가기를 누른 시점의 가격이 저장돼요'),
            const SizedBox(height: 14),
            LoadView<Map<String, ProductSummary>>(
              load: vm.products,
              onRetry: vm.reload,
              skeleton: const SkeletonCards(count: 3, height: 132, horizontal: false),
              builder: (products) => Column(
                children: [
                  if (state.visits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('아직 이동 기록이 없어요', style: AppText.caption),
                    ),
                  for (final v in state.visits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VisitCard(visit: v, product: products[v.productId]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 파란 안내 상자
class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        const EmojiImage('bulb', size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.label.copyWith(color: AppColors.blue)),
        ),
      ],
    ),
  );
}

/// 이동 기록 · 구매 기록 카드: [구매했어요] · [문제 제기]
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.visit, required this.product});

  final VisitRecord visit;
  final ProductSummary? product; // 상품 정보를 못 받았으면 이름만 비운다

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final p = product?.product;
    final name = p?.name ?? '';
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${visit.productId}?v=${visit.variantId}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${visit.whenLabel} · ${visit.mall}', style: AppText.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (p != null) GoodsThumb(emoji: p.emoji, bg: p.bg, size: 44, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name · ${visit.variantLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                        const SizedBox(height: 2),
                        Text(visit.priceLabel, style: AppText.label),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  AppButton(
                    visit.purchased ? '✓ 구매함' : '구매했어요',
                    kind: visit.purchased ? AppButtonKind.primary : AppButtonKind.secondary,
                    color: visit.purchased ? AppColors.greenBg : null,
                    textColor: visit.purchased ? AppColors.green : null,
                    expand: false,
                    height: 32,
                    fontSize: 12,
                    onPressed: () => state.markPurchased(visit.id),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    '문제 제기',
                    kind: AppButtonKind.secondary,
                    expand: false,
                    height: 32,
                    fontSize: 12,
                    onPressed: () async {
                      final sent = await showIssueSheet(context, visit: visit, productName: name);
                      if (sent == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('문의를 보냈어요. 답변이 오면 알려 드려요'),
                            action: SnackBarAction(label: '문의 내역', textColor: AppColors.orange, onPressed: () => context.go('/my/list/inquiries')),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
