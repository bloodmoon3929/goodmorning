import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../bottom_sheet/app_bottom_sheet.dart';
import '../buttons/app_button.dart';
import '../goods_thumb/goods_thumb.dart';
import '../skeleton/skeleton.dart';

/// 사진 고르기: 사진 찍기 · 앨범 · 최근 사진. 고른 사진 id를 돌려준다.
/// 홈의 📷, 사진 검색의 [다시 찍기], 판매자 상품 등록에서 쓴다.
Future<String?> showPhotoPickSheet(BuildContext context, {String title = '사진으로 찾기', String? subtitle}) {
  final api = AppScope.read(context).api;
  return showAppBottomSheet<String>(
    context,
    title: title,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle ?? '같은 굿즈와 다른 버전까지 함께 찾아 드려요', style: AppText.caption),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButton(
                '사진 찍기',
                kind: AppButtonKind.secondary,
                icon: 'camera',
                height: 48,
                radius: 12,
                fontSize: 14,
                onPressed: () {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('프로토타입: 카메라 대신 최근 사진에서 골라 주세요')));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                '앨범에서 고르기',
                kind: AppButtonKind.secondary,
                icon: 'picture',
                height: 48,
                radius: 12,
                fontSize: 14,
                onPressed: () {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('프로토타입: 아래 최근 사진에서 골라 주세요')));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text('최근 사진', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        FutureBuilder<List<SamplePhoto>>(
          future: api.recentPhotos(),
          builder: (context, snap) {
            final photos = snap.data;
            if (photos == null) return const SkeletonCards(count: 3, height: 104);
            return Row(
              children: [
                for (var i = 0; i < photos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: photos[i].label,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, photos[i].id),
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GoodsThumb(
                            emoji: photos[i].emoji,
                            bg: photos[i].bg,
                            width: double.infinity,
                            height: double.infinity,
                            radius: 12,
                            emojiScale: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text('가장 최근 사진이 먼저 보여요', style: AppText.tiny.copyWith(color: AppColors.sub)),
      ],
    ),
  );
}
