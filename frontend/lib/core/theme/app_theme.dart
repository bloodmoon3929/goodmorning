import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 글자 크기 · 굵기. 화면에서는 `AppText.title` 처럼 가져다 쓴다.
abstract final class AppText {
  static const _f = 'Pretendard';
  static const display = TextStyle(fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35);
  static const title = TextStyle(fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35);
  static const section = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35);
  static const bodyStrong = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4);
  static const body = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.ink, height: 1.4);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.4);
  static const caption = TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.sub, height: 1.4);
  static const tiny = TextStyle(fontFamily: _f, fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.sub, height: 1.35);
}

abstract final class AppGap {
  static const page = 16.0; // 화면 좌우 여백
  static const radius = 14.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange, primary: AppColors.orange, surface: AppColors.white, onSurface: AppColors.ink),
    scaffoldBackgroundColor: AppColors.white,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: AppText.title,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.label.copyWith(color: AppColors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      hintStyle: AppText.body.copyWith(color: AppColors.sub),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.orange),
  );
}
