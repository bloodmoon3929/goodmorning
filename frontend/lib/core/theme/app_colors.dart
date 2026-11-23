import 'package:flutter/material.dart';

/// 공통 요소의 색 코드. 톤은 UI 시안 표지(로그인 화면)에서 뽑았다:
/// 로고 남색 · 로고 그림자 피치 · 이타백 민트 · 카드 테두리 베이지.
/// 재고 · 판매 경로 색(파랑 · 초록 · 노랑 · 빨강)은 뜻이 있는 색이라 그대로 둔다 (docs/01-screen-flow.md).
abstract final class AppColors {
  static const primary = Color(0xFF13294B); // 표지 로고 남색 · 주요 버튼 · 선택 상태
  static const primaryBg = Color(0xFFE9EEF6);
  static const mint = Color(0xFF22C7A0); // 표지 화살표 · 이타백 · 강조 포인트
  static const mintBg = Color(0xFFE2F7F0);
  static const peach = Color(0xFFFFB896); // 로고 그림자 · 가챠 캡슐
  static const peachBg = Color(0xFFFFF1E8);
  static const cream = Color(0xFFFFF9F0); // 시안 방 꾸미기 배경
  static const cardLine = Color(0xFFEDE3D3); // 표지 카드 테두리
  static const blue = Color(0xFF2F6FED); // 온라인 배지 · 링크
  static const blueBg = Color(0xFFE8F0FE);
  static const green = Color(0xFF18A058); // 오프라인 · 재고 많음
  static const greenBg = Color(0xFFE4F6EC);
  static const amber = Color(0xFFB7791F); // 주의 · 재고 적음 · 버전 확인 안내
  static const amberBg = Color(0xFFFFF5D6);
  static const red = Color(0xFFE5484D); // 재고 없음 · 오류
  static const redBg = Color(0xFFFDECEC);
  static const ink = Color(0xFF182844); // 제목 · 본문 (표지 글자색)
  static const sub = Color(0xFF8A8F98); // 출처 · 시각
  static const line = Color(0xFFE6E8EC); // 구분선
  static const bg = Color(0xFFF4F5F7); // 입력창 배경
  static const white = Color(0xFFFFFFFF);
  static const dashed = Color(0xFFB0B5BD);
  static const unreadBg = Color(0xFFFFF6F0); // 안 읽은 알림 (피치 옅게)
}
