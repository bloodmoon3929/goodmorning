import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

/// 둘러보기(비로그인) 상태에서 찜 · 알림 · 제보 · 구매하러 가기 기록은 로그인이 필요하다.
/// 로그인한 상태면 바로 true.
Future<bool> ensureMember(BuildContext context, String action) async {
  final state = AppScope.read(context);
  if (state.isMember) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('로그인이 필요해요', style: AppText.title),
      content: Text('$action은(는) 로그인한 뒤에 쓸 수 있어요.\n찜 · 알림 · 제보 · 이동 기록이 계정에 저장돼요.', style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('나중에')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그인')),
      ],
    ),
  );
  if (go == true && context.mounted) {
    state.logout();
    context.go('/login');
  }
  return false;
}
