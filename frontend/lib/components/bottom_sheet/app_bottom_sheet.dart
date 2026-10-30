import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 아래에서 올라오는 창 (재고 제보 · 문제 제기 · 매장 미리보기 · 사진 고르기).
/// 키보드가 올라오면 창도 같이 올라간다.
Future<T?> showAppBottomSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.title.copyWith(fontSize: 19)),
              const SizedBox(height: 16),
              builder(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}
