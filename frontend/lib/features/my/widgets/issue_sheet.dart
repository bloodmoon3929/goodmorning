import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../components/bottom_sheet/app_bottom_sheet.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/chips/app_chip.dart';
import '../../../components/emoji/emoji_image.dart';
import '../../../components/skeleton/skeleton.dart';
import '../../../core/network/load_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/account.dart';
import '../my_view_model.dart';

/// 23. 문제 제기 창 — 이동 기록 · 구매 기록에서 [문제 제기]. 보내면 true.
Future<bool?> showIssueSheet(BuildContext context, {required VisitRecord visit, required String productName}) {
  final state = AppScope.read(context);
  return showAppBottomSheet<bool>(
    context,
    title: '문제 제기',
    builder: (_) => _IssueForm(vm: IssueViewModel(state, visit, productName)),
  );
}

class _IssueForm extends StatefulWidget {
  const _IssueForm({required this.vm});

  final IssueViewModel vm;

  @override
  State<_IssueForm> createState() => _IssueFormState();
}

class _IssueFormState extends State<_IssueForm> {
  IssueViewModel get vm => widget.vm;

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    await vm.send();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final v = vm.visit;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const EmojiImage('cart', size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${v.whenLabel.split(' ').first} · ${v.mall} · ${vm.productName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('어떤 문제인가요?', style: AppText.bodyStrong),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in IssueViewModel.types) AppChip(t, selected: vm.type == t, style: ChipStyle.orange, onTap: () => vm.setType(t))],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: vm.setMessage,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '예) 결제 화면에서 41,000원으로 나왔어요'),
          ),
          const SizedBox(height: 12),
          switch (vm.nowOffer) {
            Loading() => const Shimmer(child: SkeletonBox(height: 40, radius: 10)),
            Loaded(:final value) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(10)),
              child: Text(
                value == null ? '당시 가격 ${won(v.total)}이 함께 전달돼요' : '당시 가격 ${won(v.total)}과 지금 가격 ${won(value.total)}이 함께 전달돼요',
                style: AppText.caption.copyWith(color: AppColors.blue, fontWeight: FontWeight.w500),
              ),
            ),
            LoadFailed() => const SizedBox.shrink(),
          },
          const SizedBox(height: 16),
          AppButton('보내기', busy: vm.sending, onPressed: vm.canSend ? _send : null),
        ],
      );
    },
  );
}
