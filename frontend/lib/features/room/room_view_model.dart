import 'package:flutter/services.dart';

import '../../core/network/load_state.dart';
import 'room_asset.dart';

/// 내 굿즈 방 단계 (UI 시안: 360° 촬영 → 윤곽 분리 → 미리보기 → 내 방 꾸미기)
enum RoomStep {
  capture('360° 촬영'),
  segment('윤곽 분리'),
  preview('3D 복원'),
  room('내 방 꾸미기');

  const RoomStep(this.label);
  final String label;
}

/// 방 색 고르기 (시안의 벽지 · 바닥 · 선반). null = 방 그림 그대로
enum WallTone {
  pink('분홍', null),
  apricot('살구', 0xFFFFE0D0);

  const WallTone(this.label, this.color);
  final String label;
  final int? color;
}

enum FloorTone {
  ivory('아이보리', null),
  walnut('진한 원목', 0xFFBB9877);

  const FloorTone(this.label, this.color);
  final String label;
  final int? color;
}

enum ShelfTone {
  pink('분홍', null),
  oak('허니 오크', 0xFFCDA276);

  const ShelfTone(this.label, this.color);
  final String label;
  final int? color;
}

/// 방 안에서 굿즈를 놓을 수 있는 칸 (방 그림 기준 %, 시안과 같은 위치)
class RoomSlot {
  const RoomSlot(this.name, this.left, this.top, this.width, this.height);
  final String name;
  final double left, top, width, height;
}

/// 내 방 (하단 탭) — 촬영한 굿즈를 3D 에셋으로 만들어 방에 놓는다
class RoomViewModel extends ViewModel {
  RoomViewModel(this.bundle, {this.dir = 'assets/room/pochita'});

  final AssetBundle bundle;
  final String dir;

  static const slots = [
    RoomSlot('선반 위 칸', 66, 33, 10, 11),
    RoomSlot('선반 아래 칸', 66, 46, 10, 7),
    RoomSlot('테이블 위', 23, 40, 9, 12),
    RoomSlot('바닥 가운데', 44, 49, 12, 22),
  ];

  Load<RoomAsset> asset = const Loading();
  int variantIndex = 0; // 0 = 가우시안 스플래팅, 1 = SAM 3D (비교)
  RoomStep step = RoomStep.capture;
  final Set<RoomStep> done = {};
  int turn = 0; // 회전 렌더 번호
  int? placed; // 놓은 칸
  bool showInfo = false;
  WallTone wall = WallTone.pink;
  FloorTone floor = FloorTone.ivory;
  ShelfTone shelf = ShelfTone.pink;

  /// 지금 고른 3D 방법
  ReconVariant? get variant {
    final a = asset.valueOrNull;
    return a == null ? null : a.variants[variantIndex.clamp(0, a.variants.length - 1)];
  }

  /// 방법을 바꿔도 같은 각도를 보게 회전 번호는 그대로 둔다 (두 방법 모두 입력 사진 방향이 0°)
  void setVariant(int i) {
    variantIndex = i;
    notify();
  }

  Future<void> loadIfNeeded() async {
    if (asset is Loaded<RoomAsset>) return;
    await load(() => RoomAsset.load(bundle, dir), (v) => asset = v);
    final a = asset.valueOrNull;
    if (a != null) turn = a.frontIndex;
  }

  void go(RoomStep s) {
    step = s;
    showInfo = false;
    notify();
  }

  /// 한 단계를 마치고 다음으로
  void complete(RoomStep s) {
    done.add(s);
    final next = RoomStep.values.indexOf(s) + 1;
    if (next < RoomStep.values.length) step = RoomStep.values[next];
    notify();
  }

  /// 단계 표시를 눌러 이동: 이미 지난 단계나 바로 다음 단계만
  bool canOpen(RoomStep s) => s == step || done.contains(s) || (s.index > 0 && done.contains(RoomStep.values[s.index - 1]));

  void openRoomDirectly() {
    done.addAll([RoomStep.capture, RoomStep.segment, RoomStep.preview]);
    go(RoomStep.room);
  }

  void restart() {
    done.clear();
    placed = null;
    showInfo = false;
    turn = asset.valueOrNull?.frontIndex ?? 0;
    step = RoomStep.capture;
    notify();
  }

  /// 손가락으로 끈 만큼 돌린다 (6px = 한 장)
  void rotateBy(double dx) {
    final a = asset.valueOrNull;
    if (a == null) return;
    final steps = (dx / 6).round();
    if (steps == 0) return;
    turn = (turn - steps) % variant!.count;
    notify();
  }

  void setTurn(int i) {
    final a = asset.valueOrNull;
    if (a == null) return;
    turn = i % variant!.count;
    notify();
  }

  void place(int slot) {
    placed = slot;
    showInfo = false;
    done.add(RoomStep.room);
    notify();
  }

  void toggleInfo() {
    if (placed == null) return;
    showInfo = !showInfo;
    notify();
  }

  void setWall(WallTone t) {
    wall = t;
    notify();
  }

  void setFloor(FloorTone t) {
    floor = t;
    notify();
  }

  void setShelf(ShelfTone t) {
    shelf = t;
    notify();
  }
}
