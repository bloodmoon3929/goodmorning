import 'package:flutter_test/flutter_test.dart';
import 'package:goodmorning/features/room/capture/capture_guide.dart';

/// 자동 촬영 가이드 판단: 높이 줄 · 방향 칸 · 멈춤 · 흔들림
void main() {
  test('멈춰 있으면 지금 칸을 찍고, 찍은 칸은 다시 찍지 않는다', () {
    final g = CaptureGuide();
    expect(g.update(downDeg: 10, headingDeg: 100, nowMs: 0), isNull); // 처음 방향이 0°
    expect(g.hint, GuideHint.hold);
    final cell = g.update(downDeg: 10, headingDeg: 100, nowMs: 400);
    expect(cell, (ring: 0, sector: 0));
    g.markDone(cell!);
    expect(g.update(downDeg: 10, headingDeg: 101, nowMs: 800), isNull);
    expect(g.hint, GuideHint.moveOn);
    expect(g.countIn(0), 1);
  });

  test('방향 칸은 처음 방향 기준 15°씩, 높이는 숙인 각도로 줄을 고른다', () {
    final g = CaptureGuide();
    g.update(downDeg: 10, headingDeg: 350, nowMs: 0);
    g.update(downDeg: 30, headingDeg: 350 + 47, nowMs: 2000); // 47° → 3번째 칸(0부터), 중간 줄
    expect(g.currentSector, 3);
    expect(g.currentRing, 1);
    g.update(downDeg: 60, headingDeg: 340, nowMs: 4000); // -10° → 23번째 칸, 높게
    expect(g.currentSector, 23);
    expect(g.currentRing, 2);
  });

  test('빨리 움직이면 찍지 않고 천천히 하라고 한다', () {
    final g = CaptureGuide();
    g.update(downDeg: 10, headingDeg: 0, nowMs: 0);
    expect(g.update(downDeg: 10, headingDeg: 40, nowMs: 100), isNull); // 400°/초
    expect(g.hint, GuideHint.slowDown);
  });

  test('범위 밖이면 숙이거나 세우라고 한다', () {
    final g = CaptureGuide();
    g.update(downDeg: -15, headingDeg: 0, nowMs: 0);
    expect(g.hint, GuideHint.tiltDown);
    g.update(downDeg: 85, headingDeg: 0, nowMs: 2000);
    expect(g.hint, GuideHint.tiltUp);
  });

  test('한 줄을 다 찍으면 다음 줄을 권하고, 72칸이면 끝', () {
    final g = CaptureGuide();
    for (var s = 0; s < g.sectors; s++) {
      g.markDone((ring: 0, sector: s));
    }
    expect(g.suggestedRing, 1);
    g.update(downDeg: 10, headingDeg: 0, nowMs: 0);
    expect(g.hint, GuideHint.ringDone);
    for (var r = 1; r < 3; r++) {
      for (var s = 0; s < g.sectors; s++) {
        g.markDone((ring: r, sector: s));
      }
    }
    expect(g.finished, isTrue);
    g.update(downDeg: 10, headingDeg: 0, nowMs: 1000);
    expect(g.hint, GuideHint.allDone);
    g.reset();
    expect(g.done, isEmpty);
  });
}
