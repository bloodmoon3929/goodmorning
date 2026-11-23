import 'dart:convert';

import 'package:flutter/services.dart';

/// 3D로 만든 방법 하나 (가우시안 스플래팅 · SAM 3D …)와 그 결과를 한 바퀴 돌려 렌더링한 그림
class ReconVariant {
  const ReconVariant({
    required this.id,
    required this.label,
    required this.method,
    required this.prefix,
    required this.count,
    required this.views,
    required this.gaussians,
    this.poses,
    this.psnr,
    this.seconds,
  });

  final String id;
  final String label; // 고르는 칩 글자
  final String method;
  final String prefix; // 회전 렌더 파일 이름 앞부분 (turn_ · sam3d_turn_)
  final int count;
  final int views; // 3D를 만들 때 쓴 사진 수
  final int gaussians;
  final String? poses; // 카메라 위치를 구한 방법 (여러 장일 때)
  final double? psnr; // 학습에 쓰지 않은 사진으로 잰 값
  final double? seconds; // 만드는 데 걸린 시간 (추론)

  bool get singlePhoto => views == 1;
}

/// 촬영한 굿즈 하나를 3D 에셋으로 만든 결과 (backend/ai/asset3d 파이프라인이 manifest.json과 그림을 내보낸다).
///   capture_NN.jpg  — 실제 촬영 영상에서 고른 프레임
///   segment_NN.jpg  — 같은 프레임에 SAM 3가 자른 굿즈 영역을 표시한 것
///   turn_NN.webp    — 가우시안 스플래팅 결과를 한 바퀴 돌려 가며 렌더링한 것 (배경 투명)
///   sam3d_turn_NN.webp — 비교용: SAM 3D Objects(사진 1장 → 3D) 결과를 같은 카메라로 렌더링한 것
class RoomAsset {
  const RoomAsset({
    required this.dir,
    required this.name,
    required this.captureCount,
    required this.segmentCount,
    required this.frontIndex,
    required this.videoSeconds,
    required this.videoFrames,
    required this.segmentModel,
    required this.segmentPrompt,
    required this.variants,
  });

  final String dir;
  final String name;
  final int captureCount;
  final int segmentCount;
  final int frontIndex; // 정면을 보는 회전 렌더 번호
  final double videoSeconds;
  final int videoFrames;
  final String segmentModel;
  final String segmentPrompt;
  final List<ReconVariant> variants; // 0번 = 가우시안 스플래팅

  static String _two(int i) => i.toString().padLeft(2, '0');
  String capture(int i) => '$dir/capture_${_two(i % captureCount)}.jpg';
  String segment(int i) => '$dir/segment_${_two(i % segmentCount)}.jpg';
  String turnOf(ReconVariant v, int i) => '$dir/${v.prefix}${_two(i % v.count)}.webp';

  static Future<RoomAsset> load(AssetBundle bundle, String dir) async {
    final j = jsonDecode(await bundle.loadString('$dir/manifest.json')) as Map<String, dynamic>;
    final video = j['video'] as Map<String, dynamic>;
    final seg = j['segment'] as Map<String, dynamic>;
    final recon = j['recon'] as Map<String, dynamic>;
    final turn = j['turntable'] as Map<String, dynamic>;
    return RoomAsset(
      dir: dir,
      name: j['name'] as String,
      captureCount: (j['capture'] as Map<String, dynamic>)['count'] as int,
      segmentCount: seg['count'] as int,
      frontIndex: turn['front'] as int? ?? 0,
      videoSeconds: (video['seconds'] as num).toDouble(),
      videoFrames: video['frames'] as int,
      segmentModel: seg['model'] as String,
      segmentPrompt: seg['prompt'] as String,
      variants: [
        ReconVariant(
          id: 'gs',
          label: '가우시안 스플래팅 (영상)',
          method: recon['method'] as String,
          prefix: 'turn_',
          count: turn['count'] as int,
          views: recon['views'] as int,
          gaussians: recon['gaussians'] as int,
          poses: recon['poses'] as String?,
          psnr: (recon['psnr'] as num?)?.toDouble(),
        ),
        for (final c in (j['compare'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>())
          ReconVariant(
            id: c['id'] as String,
            label: c['label'] as String,
            method: c['method'] as String,
            prefix: c['prefix'] as String,
            count: c['count'] as int,
            views: c['views'] as int,
            gaussians: c['gaussians'] as int,
            seconds: (c['seconds'] as num?)?.toDouble(),
          ),
      ],
    );
  }
}
