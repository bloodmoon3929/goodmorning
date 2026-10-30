import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmorning/app/app.dart';
import 'package:goodmorning/core/network/mock_api.dart';

/// 화면 흐름 테스트: 지연 없는 목업 API로 앱을 띄우고 PPT의 주요 동선을 눌러 본다.
/// 스켈레톤의 반짝임이 계속 돌아서 pumpAndSettle 대신 시간을 조금씩 흘린다.
Future<void> settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> start(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GoodmorningApp(api: MockGoodmorningApi(latency: false)));
  await settle(t);
}

Future<void> loginAsMember(WidgetTester t) async {
  await t.tap(find.text('로그인'));
  await settle(t, 10);
}

/// 테스트 기본 글꼴은 글자마다 네모 한 칸이라 한글 폭이 실제보다 넓다. 앱과 같은 Pretendard를 올려서 배치를 맞춘다.
Future<void> loadPretendard() async {
  final loader = FontLoader('Pretendard');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Pretendard-$w.otf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadPretendard);

  testWidgets('로그인 없이 둘러보기 → 홈 → 매장 찾기 → 매장 상세', (t) async {
    await start(t);
    expect(find.text('굿즈 모으는 닝겐'), findsOneWidget);

    await t.tap(find.text('로그인 없이 둘러보기 ›'));
    await settle(t);
    expect(find.text('굿즈 이름, 캐릭터 검색'), findsOneWidget);

    await t.tap(find.text('매장 찾기').last);
    await settle(t);
    expect(find.text('피규어샵 용산점'), findsWidgets);

    await t.tap(find.text('피규어샵 용산점').first);
    await settle(t);
    expect(find.text('재고가 다른가요? 제보하기 ›'), findsOneWidget);
    expect(find.text('RG 1/144 RX-78-2 건담'), findsWidgets);
  });

  testWidgets('매장 찾기: 리스트 ↔ 지도, 마커를 누르면 미리보기', (t) async {
    await start(t);
    await loginAsMember(t);
    await t.tap(find.text('매장 찾기').last);
    await settle(t);

    await t.tap(find.text('지도'));
    await settle(t);
    expect(find.text('마커를 누르면 매장 정보를 볼 수 있어요'), findsOneWidget);

    await t.tap(find.bySemanticsLabel(RegExp('^피규어샵 용산점')));
    await settle(t);
    expect(find.text('매장 상세 ›'), findsOneWidget);
  });

  testWidgets('이동 기록: 구매했어요를 누르면 구매함으로 바뀐다', (t) async {
    await start(t);
    await loginAsMember(t);
    await t.tap(find.text('마이').last);
    await settle(t);
    await t.tap(find.text('이동 기록'));
    await settle(t);

    expect(find.text('✓ 구매함'), findsOneWidget);
    await t.tap(find.text('구매했어요').first);
    await settle(t, 3);
    expect(find.text('✓ 구매함'), findsNWidgets(2));
  });

  testWidgets('판매자 센터: 재고를 바꾸면 변경 저장 버튼에 건수가 보인다', (t) async {
    await start(t);
    await loginAsMember(t);
    await t.tap(find.text('마이').last);
    await settle(t);
    await t.tap(find.text('사장님이신가요?'));
    await settle(t);

    expect(find.text('오늘 재고 그대로예요'), findsOneWidget);
    expect(find.text('변경 저장'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('재고 없음').first);
    await settle(t, 3);
    expect(find.text('변경 저장 (1건)'), findsOneWidget);

    await t.tap(find.text('변경 저장 (1건)'));
    await settle(t);
    expect(find.text('변경 저장'), findsOneWidget);
    expect(find.textContaining('마지막 확인: 방금 전'), findsOneWidget);
  });
}
