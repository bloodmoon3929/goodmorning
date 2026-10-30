import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../buttons/app_button.dart';
import '../emoji/emoji_image.dart';

enum ExternalKind { mall, map, phone }

/// 앱 밖으로 나가는 동작 (외부 쇼핑몰 · 지도 앱 길찾기 · 전화 앱).
/// 프로토타입이라 실제로 나가지 않고 어디로 가는지만 보여 준다.
Future<void> showExternalMove(BuildContext context, {required ExternalKind kind, required String target, String? detail}) {
  final (emoji, title, body) = switch (kind) {
    ExternalKind.mall => ('bags', '$target로 이동해요', detail ?? '구매하러 가기를 누른 시점의 가격을 이동 기록에 저장했어요'),
    ExternalKind.map => ('map', '지도 앱으로 길찾기', '$target까지 길찾기를 지도 앱에서 열어요'),
    ExternalKind.phone => ('phone', '전화 앱으로 연결', '$target${detail == null ? '' : ' ($detail)'}에 전화를 걸어요'),
  };
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmojiImage(emoji, size: 72),
            const SizedBox(height: 12),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppText.body.copyWith(color: AppColors.sub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('프로토타입이라 실제로 이동하지는 않아요', style: AppText.caption),
            const SizedBox(height: 20),
            if (kind == ExternalKind.mall) ...[
              AppButton(
                '이동 기록 보기',
                kind: AppButtonKind.secondary,
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/my/history');
                },
              ),
              const SizedBox(height: 8),
            ],
            AppButton('굿모닝으로 돌아가기', height: 50, onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ),
  );
}
