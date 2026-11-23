import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmorning/app/app.dart';
import 'package:goodmorning/components/ip_tile/ip_tile.dart';
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

/// 표지와 같은 로그인 화면: SNS로 처음 들어오면 IP를 고르고 시작한다
Future<void> loginAsMember(WidgetTester t) async {
  await t.tap(find.text('카카오'));
  await settle(t, 10);
  await t.tap(find.byType(IpTileGrid).first);
  await settle(t, 3);
  await t.tap(find.textContaining('굿모닝 시작하기'));
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

  testWidgets('로그인 없이 모아보기 → 홈 → 매장 찾기 → 매장 상세', (t) async {
    await start(t);
    expect(find.text('SNS로 모으러 가기'), findsOneWidget);
    for (final sns in ['카카오', '네이버', '구글', 'Apple']) {
      expect(find.text(sns), findsOneWidget);
    }

    await t.tap(find.text('로그인 없이 모아보기'));
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

  testWidgets('내 방: 촬영 → 윤곽 분리 → 3D 미리보기 → 방에 놓고 상품 정보', (t) async {
    await start(t);
    await loginAsMember(t);
    await t.tap(find.text('내 방').last);
    await settle(t, 6);
    expect(find.text('내 굿즈 방'), findsOneWidget);
    expect(find.textContaining('실제 영상이에요'), findsOneWidget);

    // 촬영 영상이 끝나면 윤곽 분리가 이어서 재생되고, 끝나면 3D 미리보기
    await t.ensureVisible(find.text('촬영 영상 재생'));
    await t.tap(find.text('촬영 영상 재생'));
    for (var i = 0; i < 18; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(find.text('3D 에셋 미리보기'), findsOneWidget);
    expect(find.textContaining('가우시안'), findsWidgets);

    // 같은 각도에서 SAM 3D(사진 1장) 결과로 바꿔 비교
    await t.ensureVisible(find.text('SAM 3D (사진 1장)'));
    await t.tap(find.text('SAM 3D (사진 1장)'));
    await settle(t, 2);
    expect(find.text('영상 첫 프레임 1장 + SAM 3 마스크'), findsOneWidget);
    await t.tap(find.text('가우시안 스플래팅 (영상)'));
    await settle(t, 2);
    expect(find.textContaining('흔들린 프레임 제외'), findsOneWidget);

    await t.ensureVisible(find.text('에셋을 내 방으로 가져가기'));
    await t.tap(find.text('에셋을 내 방으로 가져가기'));
    await settle(t);
    expect(find.textContaining('끌어 놓으세요'), findsOneWidget);
    expect(find.text('굿즈 정보 보기'), findsOneWidget);

    // 트레이를 누르면 첫 칸에 놓이고, 정보 보기를 누르면 구매처 안내
    await t.ensureVisible(find.bySemanticsLabel('포치타 인형 배치'));
    await t.tap(find.bySemanticsLabel('포치타 인형 배치'));
    await settle(t, 3);
    expect(find.text('선반 위 칸에 놓았어요 · 0° 방향'), findsOneWidget);

    // 놓은 굿즈를 누르면 360° 돌려 전시 방향 정하기: 취소하면 그대로, 정하면 그 방향으로
    await t.tap(find.bySemanticsLabel(RegExp('^선반 위 칸에 놓은 굿즈')));
    await settle(t, 3);
    expect(find.text('전시 방향 정하기'), findsOneWidget);
    await t.tap(find.text('뒤 180°'));
    await settle(t, 2);
    expect(find.text('선반 위 칸에 놓았어요 · 180° 방향'), findsOneWidget); // 돌리는 동안 방에도 보인다
    await t.tap(find.text('취소'));
    await settle(t, 3);
    expect(find.text('선반 위 칸에 놓았어요 · 0° 방향'), findsOneWidget);

    await t.tap(find.bySemanticsLabel(RegExp('^선반 위 칸에 놓은 굿즈')));
    await settle(t, 3);
    await t.tap(find.text('옆 90°'));
    await settle(t, 2);
    await t.tap(find.text('이 방향으로 전시 (90°)'));
    await settle(t, 3);
    expect(find.text('전시 방향 정하기'), findsNothing);
    expect(find.text('선반 위 칸에 놓았어요 · 90° 방향'), findsOneWidget);
    await t.ensureVisible(find.text('살구'));
    await t.tap(find.text('살구'));
    await settle(t, 2);
    await t.ensureVisible(find.text('굿즈 정보 보기'));
    await t.tap(find.text('굿즈 정보 보기'));
    await settle(t, 3);
    expect(find.text('등록된 구매처가 없어요.'), findsOneWidget);
  });
}
