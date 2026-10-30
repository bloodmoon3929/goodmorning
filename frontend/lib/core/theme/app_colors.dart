import 'package:flutter/material.dart';

/// 공통 요소의 색 코드 (docs/01-screen-flow.md · PPT 3번 슬라이드).
abstract final class AppColors {
  static const orange = Color(0xFFFF7A2F); // 굿모닝 주황 · 주요 버튼 · 선택 상태
  static const orangeBg = Color(0xFFFFF0E6);
  static const blue = Color(0xFF2F6FED); // 온라인 배지 · 링크
  static const blueBg = Color(0xFFE8F0FE);
  static const green = Color(0xFF18A058); // 오프라인 · 재고 많음
  static const greenBg = Color(0xFFE4F6EC);
  static const amber = Color(0xFFB7791F); // 주의 · 재고 적음 · 버전 확인 안내
  static const amberBg = Color(0xFFFFF5D6);
  static const red = Color(0xFFE5484D); // 재고 없음 · 오류
  static const redBg = Color(0xFFFDECEC);
  static const ink = Color(0xFF1F2329); // 제목 · 본문
  static const sub = Color(0xFF8A8F98); // 출처 · 시각
  static const line = Color(0xFFE3E6EA); // 구분선
  static const bg = Color(0xFFF4F5F7); // 입력창 배경
  static const white = Color(0xFFFFFFFF);
  static const dashed = Color(0xFFB0B5BD);
  static const unreadBg = Color(0xFFFFF8F3);
}
