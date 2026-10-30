import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 회원가입 단계 표시: 1. 계정 정보 → 2. IP 선택
class SignupSteps extends StatelessWidget {
  const SignupSteps({super.key, required this.active});

  final int active; // 1 또는 2

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(
      children: [
        for (final (i, label) in [(1, '1. 계정 정보'), (2, '2. IP 선택')]) ...[
          if (i == 2) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(color: i == active ? AppColors.orange : AppColors.line, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == active ? FontWeight.w600 : FontWeight.w500,
                    color: i == active ? AppColors.orange : AppColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
