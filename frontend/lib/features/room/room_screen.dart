import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/buttons/app_button.dart';
import '../../components/chips/app_chip.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'room_asset.dart';
import 'room_view_model.dart';
import 'widgets/flipbook.dart';
import 'widgets/mini_room.dart';
import 'widgets/orientation_sheet.dart';
import 'widgets/turntable.dart';

/// 내 방 (하단 탭) — UI 시안(시안.html)의 흐름:
/// 360° 촬영 → 윤곽 분리(SAM 3) → 3D 복원(가우시안 스플래팅) → 내 방 꾸미기(칸에 놓기 · 회전 · 상품 정보)
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final vm = RoomViewModel(DefaultAssetBundle.of(context));
  bool _playing = false;
  double _progress = 0;
  bool _dragging = false;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    vm.loadIfNeeded().then((_) => _precache());
  }

  /// 프레임을 넘길 때 깜빡이지 않게 미리 불러 둔다
  void _precache() {
    final a = vm.asset.valueOrNull;
    if (a == null || _precached || !mounted) return;
    _precached = true;
    for (var i = 0; i < a.captureCount; i++) {
      precacheImage(AssetImage(a.capture(i)), context);
    }
    for (var i = 0; i < a.segmentCount; i++) {
      precacheImage(AssetImage(a.segment(i)), context);
    }
    for (final v in a.variants) {
      for (var i = 0; i < v.count; i++) {
        precacheImage(AssetImage(a.turnOf(v, i)), context);
      }
    }
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _play() => setState(() {
    _playing = true;
    _progress = 0;
  });

  void _finish(RoomStep s) {
    setState(() => _playing = false);
    vm.complete(s);
    // 촬영이 끝나면 바로 윤곽 분리를 이어서 보여 준다 (시안과 같은 흐름)
    if (s == RoomStep.capture) _play();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => LoadView<RoomAsset>(
          load: vm.asset,
          skeleton: const Padding(padding: EdgeInsets.all(16), child: SkeletonBox(height: 420)),
          onRetry: vm.loadIfNeeded,
          // 내용이 짧아서 한 번에 다 그린다 (단계마다 버튼 · 정보가 화면 아래에 붙음)
          builder: (a) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 12),
                _steps(),
                const SizedBox(height: 12),
                _stage(a),
                const SizedBox(height: 12),
                ..._below(a),
                const SizedBox(height: 18),
                Text(
                  '촬영 영상(${a.videoSeconds.toStringAsFixed(1)}초)부터 3D 복원까지는 같은 영상으로 PC에서 미리 계산한 실제 결과입니다. '
                  '앱 안에서 바로 계산하지는 않습니다. 100원 동전 크기 기준은 이 영상에 없어서 넣지 않았습니다.',
                  style: AppText.tiny,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 굿즈 방', style: AppText.display.copyWith(fontSize: 26, letterSpacing: -0.8)),
            Text('촬영한 굿즈를 3D로 만들어 방에 꾸며요', style: AppText.caption),
          ],
        ),
      ),
      ExcludeSemantics(child: Image.asset('assets/brand/itabag.png', height: 54)),
    ],
  );

  // 지난 단계는 ✓ (글자가 길어지면 한 줄 안에서 옆으로 넘긴다)
  Widget _steps() => Semantics(
    label: '단계',
    child: ChipRow(
      padding: EdgeInsets.zero,
      children: [
        for (final s in RoomStep.values)
          AppChip(
            vm.done.contains(s) && s != vm.step ? '✓ ${s.label}' : s.label,
            size: 12,
            selected: s == vm.step,
            onTap: vm.canOpen(s) && !_playing ? () => vm.go(s) : null,
          ),
      ],
    ),
  );

  Widget _stage(RoomAsset a) {
    if (vm.step == RoomStep.room) {
      return MiniRoom(vm: vm, assetPath: (t) => a.turnOf(vm.variant!, t), dragging: _dragging, onPlacedTap: () => _orient(a));
    }
    final Widget content = switch (vm.step) {
      RoomStep.capture => Flipbook(
        key: const ValueKey(RoomStep.capture),
        count: a.captureCount,
        path: a.capture,
        playing: _playing,
        duration: Duration(milliseconds: _reduced ? 400 : 4800),
        onProgress: (p) => setState(() => _progress = p),
        onDone: () => _finish(RoomStep.capture),
      ),
      RoomStep.segment => Flipbook(
        key: const ValueKey(RoomStep.segment),
        count: a.segmentCount,
        path: a.segment,
        playing: _playing,
        duration: Duration(milliseconds: _reduced ? 300 : 3600),
        onProgress: (p) => setState(() => _progress = p),
        onDone: () => _finish(RoomStep.segment),
      ),
      _ => Padding(
        padding: const EdgeInsets.all(12),
        child: Turntable(
          count: vm.variant!.count,
          index: vm.turn,
          path: (i) => a.turnOf(vm.variant!, i),
          onRotate: vm.rotateBy,
          onSetIndex: vm.setTurn,
          autoSpin: true,
        ),
      ),
    };
    final label = switch (vm.step) {
      RoomStep.capture => _playing ? '촬영 중 · ${(_progress * 360).round()}°' : '손 위에서 360° 촬영',
      RoomStep.segment => '${a.segmentModel} · "${a.segmentPrompt}"',
      _ => '${vm.variant!.label} · ${(vm.turn * 360 / vm.variant!.count).round()}°',
    };
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const RadialGradient(center: Alignment.topCenter, radius: 1.3, colors: [Color(0xFFFEFBF1), Color(0xFFE6D3BD)]),
          boxShadow: const [BoxShadow(color: Color(0x25463018), blurRadius: 28, offset: Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(child: content),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xEDFFF9E9), borderRadius: BorderRadius.circular(12)),
                  child: Text(label, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _below(RoomAsset a) {
    switch (vm.step) {
      case RoomStep.capture:
        return [
          _status('손 위에서 360° 촬영', '포치타 인형을 손에 들고 한 바퀴 돌려 찍은 실제 영상이에요 (${a.videoFrames}프레임).'),
          _progressBar(),
          const SizedBox(height: 12),
          _buttons(AppButton('촬영 영상 재생', onPressed: _playing ? null : _play, busy: _playing)),
          const SizedBox(height: 8),
          AppButton(
            '내 굿즈 직접 촬영하기 (자동 촬영 가이드)',
            kind: AppButtonKind.soft,
            height: 46,
            fontSize: 14,
            onPressed: _playing ? null : () => context.push('/capture'),
          ),
          const SizedBox(height: 4),
          Text('높이 3줄 × 방향 24칸을 멈출 때마다 자동으로 찍어요. 찍은 사진 묶음으로 PC에서 3D를 만듭니다.', style: AppText.caption),
        ];
      case RoomStep.segment:
        return [
          _status('굿즈 영역 분리', '${a.segmentModel}가 프레임마다 굿즈만 잘라냈어요. 손과 종이 태그는 빼고 학습해요.'),
          _progressBar(),
          const SizedBox(height: 12),
          _buttons(AppButton(_playing ? '분리 중' : '분리 결과 다시 보기', onPressed: _playing ? null : _play, busy: _playing)),
        ];
      case RoomStep.preview:
        return [
          _status('3D 에셋 미리보기', '인형을 좌우로 끌어 돌려보세요. 방법을 바꿔 같은 각도에서 비교할 수 있어요.'),
          _variants(a),
          _facts(a),
          const SizedBox(height: 12),
          _buttons(AppButton('에셋을 내 방으로 가져가기', onPressed: () => vm.complete(RoomStep.preview))),
        ];
      case RoomStep.room:
        return [
          _status('내 굿즈 방', vm.placed == null ? '벽지 · 바닥 · 선반 색을 고르고 굿즈를 배치해 보세요.' : '놓은 인형을 누르면 360° 돌려 전시 방향을 정할 수 있어요.'),
          const SizedBox(height: 4),
          _variants(a),
          _tray(a),
          const SizedBox(height: 12),
          _tones(),
          if (vm.showInfo) ...[const SizedBox(height: 12), _info(a)],
          const SizedBox(height: 12),
          _buttons(AppButton('굿즈 정보 보기', onPressed: vm.placed == null ? null : vm.toggleInfo), restart: true),
        ];
    }
  }

  /// 놓은 굿즈 → 전시 방향 정하기 (돌리는 동안 방에 바로 보이고, 취소하면 원래대로)
  Future<void> _orient(RoomAsset a) async {
    final before = vm.displayTurn;
    final v = vm.variant!;
    final picked = await OrientationSheet.show(
      context,
      count: v.count,
      initial: before,
      path: (t) => a.turnOf(v, t),
      onPreview: vm.setDisplayTurn,
      onInfo: () {
        if (!vm.showInfo) vm.toggleInfo();
      },
    );
    vm.setDisplayTurn(picked ?? before);
  }

  Widget _status(String title, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.section),
        const SizedBox(height: 2),
        Text(hint, style: AppText.body.copyWith(color: const Color(0xFF546254))),
      ],
    ),
  );

  Widget _progressBar() => Semantics(
    label: '진행률',
    value: '${(_progress * 100).round()}%',
    child: Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _progress, minHeight: 10, color: AppColors.mint, backgroundColor: AppColors.cardLine),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text('${(_progress * 100).round()}%', style: AppText.label, textAlign: TextAlign.right),
        ),
      ],
    ),
  );

  /// 3D 방법 고르기 (비교 결과가 있을 때만)
  Widget _variants(RoomAsset a) => a.variants.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChipRow(
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < a.variants.length; i++)
                AppChip(a.variants[i].label, size: 12, style: ChipStyle.point, selected: vm.variantIndex == i, onTap: () => vm.setVariant(i)),
            ],
          ),
        );

  Widget _facts(RoomAsset a) {
    final v = vm.variant!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fact('복원 방법', v.method),
          if (v.singlePhoto) ...[
            _fact('쓴 사진', '영상 첫 프레임 1장 + SAM 3 마스크'),
            if (v.seconds != null) _fact('걸린 시간', '${v.seconds!.toStringAsFixed(0)}초 (GPU A6000, 모델 불러오기 제외)'),
            _fact('가우시안 수', '${v.gaussians}개'),
            _fact('주의', '사진에 안 보인 면(뒤 · 꼬리)은 모델이 추정해서 채워요. 표면은 깨끗하지만 실제 모양과 다를 수 있어요'),
          ] else ...[
            if (v.poses != null) _fact('카메라 위치', v.poses!),
            _fact('학습에 쓴 사진', '${v.views}장 (흔들린 프레임 제외)'),
            _fact('가우시안 수', '${v.gaussians}개'),
            if (v.psnr != null) _fact('확인용 사진 재현도', 'PSNR ${v.psnr!.toStringAsFixed(1)}dB (학습에 안 쓴 사진 기준)'),
            _fact('주의', '영상에 찍힌 면은 실제대로 나오지만 가장자리에 잡티가 남아요'),
          ],
        ],
      ),
    );
  }

  Widget _fact(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(k, style: AppText.caption)),
        Expanded(child: Text(v, style: AppText.label)),
      ],
    ),
  );

  Widget _tray(RoomAsset a) {
    final thumb = Image.asset(a.turnOf(vm.variant!, a.frontIndex), height: 58);
    return Row(
      children: [
        Draggable<String>(
          data: a.name,
          onDragStarted: () => setState(() => _dragging = true),
          onDragEnd: (_) => setState(() => _dragging = false),
          feedback: SizedBox(width: 90, height: 90, child: Image.asset(a.turnOf(vm.variant!, vm.turn))),
          childWhenDragging: Opacity(opacity: 0.35, child: _trayBox(thumb)),
          child: Semantics(
            button: true,
            label: '${a.name} 배치',
            child: GestureDetector(onTap: () => vm.place(vm.placed ?? 0), child: _trayBox(thumb)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            vm.placed == null ? '인형을 점선 칸으로 끌어 놓으세요. 눌러서 배치할 수도 있어요.' : '${RoomViewModel.slots[vm.placed!].name}에 놓았어요 · ${vm.displayDegrees}° 방향',
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  Widget _trayBox(Widget child) => Container(
    width: 72,
    height: 76,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardLine),
    ),
    child: child,
  );

  Widget _tones() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _toneRow('벽지', [for (final t in WallTone.values) AppChip(t.label, size: 12, style: ChipStyle.point, selected: vm.wall == t, onTap: () => vm.setWall(t))]),
      const SizedBox(height: 6),
      _toneRow('바닥', [
        for (final t in FloorTone.values) AppChip(t.label, size: 12, style: ChipStyle.point, selected: vm.floor == t, onTap: () => vm.setFloor(t)),
      ]),
      const SizedBox(height: 6),
      _toneRow('선반', [
        for (final t in ShelfTone.values) AppChip(t.label, size: 12, style: ChipStyle.point, selected: vm.shelf == t, onTap: () => vm.setShelf(t)),
      ]),
    ],
  );

  Widget _toneRow(String label, List<Widget> chips) => Row(
    children: [
      SizedBox(width: 36, child: Text(label, style: AppText.label)),
      Expanded(child: Wrap(spacing: 6, children: chips)),
    ],
  );

  Widget _info(RoomAsset a) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAF0),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDED4C0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${a.name} (내가 찍은 에셋)', style: AppText.bodyStrong),
        const SizedBox(height: 4),
        Text('등록된 구매처가 없어요.', style: AppText.body),
        const SizedBox(height: 2),
        Text('공식 상품과 연결하면 상품명과 구매처가 여기에 보여요.', style: AppText.caption),
      ],
    ),
  );

  Widget _buttons(Widget primary, {bool restart = false}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(width: double.infinity, child: primary),
      if (vm.step != RoomStep.room)
        AppButton('내 방 바로 열기', kind: AppButtonKind.secondary, expand: false, height: 44, fontSize: 14, onPressed: _playing ? null : vm.openRoomDirectly),
      AppButton(
        '처음으로',
        kind: AppButtonKind.secondary,
        expand: false,
        height: 44,
        fontSize: 14,
        onPressed: _playing
            ? null
            : () {
                setState(() => _progress = 0);
                vm.restart();
              },
      ),
    ],
  );
}
