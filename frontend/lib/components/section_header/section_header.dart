import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 영역 제목 + 오른쪽 "전체 ›" 같은 더보기.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.sub, this.more, this.onMore, this.padding = const EdgeInsets.fromLTRB(16, 18, 8, 8)});

  final String title;
  final String? sub;
  final String? more;
  final VoidCallback? onMore;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: AppText.section),
        if (sub != null) ...[const SizedBox(width: 8), Text(sub!, style: AppText.caption)],
        const Spacer(),
        if (more != null)
          TextButton(
            onPressed: onMore,
            style: TextButton.styleFrom(
              foregroundColor: AppText.caption.color,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 32),
            ),
            child: Text('$more ›', style: AppText.label.copyWith(color: AppText.caption.color)),
          ),
      ],
    ),
  );
}
