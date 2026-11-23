import 'dart:convert';

import 'package:flutter/services.dart';

/// 촬영한 굿즈 하나를 3D 에셋으로 만든 결과 (asset3d/ 파이프라인이 manifest.json과 그림을 내보낸다).
///   capture_NN.jpg  — 실제 촬영 영상에서 고른 프레임
///   segment_NN.jpg  — 같은 프레임에 SAM 3가 자른 굿즈 영역을 표시한 것
///   turn_NN.webp    — 가우시안 스플래팅 결과를 한 바퀴 돌려 가며 렌더링한 것 (배경 투명)
class RoomAsset {
  const RoomAsset({
    required this.dir,
    required this.name,
    required this.captureCount,
    required this.segmentCount,
    required this.turnCount,
    required this.frontIndex,
    required this.videoSeconds,
    required this.videoFrames,
    required this.segmentModel,
    required this.segmentPrompt,
    required this.poseMethod,
    required this.reconMethod,
    required this.trainViews,
    required this.gaussians,
    required this.psnr,
  });

  final String dir;
  final String name;
  final int captureCount;
  final int segmentCount;
  final int turnCount;
  final int frontIndex; // 정면을 보는 회전 렌더 번호
  final double videoSeconds;
  final int videoFrames;
  final String segmentModel;
  final String segmentPrompt;
  final String poseMethod;
  final String reconMethod;
  final int trainViews;
  final int gaussians;
  final double? psnr; // 학습에 쓰지 않은 사진으로 잰 값

  static String _two(int i) => i.toString().padLeft(2, '0');
  String capture(int i) => '$dir/capture_${_two(i % captureCount)}.jpg';
  String segment(int i) => '$dir/segment_${_two(i % segmentCount)}.jpg';
  String turn(int i) => '$dir/turn_${_two(i % turnCount)}.webp';

  static Future<RoomAsset> load(AssetBundle bundle, String dir) async {
    final j = jsonDecode(await bundle.loadString('$dir/manifest.json')) as Map<String, dynamic>;
    final video = j['video'] as Map<String, dynamic>;
    final seg = j['segment'] as Map<String, dynamic>;
    final recon = j['recon'] as Map<String, dynamic>;
    return RoomAsset(
      dir: dir,
      name: j['name'] as String,
      captureCount: (j['capture'] as Map<String, dynamic>)['count'] as int,
      segmentCount: seg['count'] as int,
      turnCount: (j['turntable'] as Map<String, dynamic>)['count'] as int,
      frontIndex: (j['turntable'] as Map<String, dynamic>)['front'] as int? ?? 0,
      videoSeconds: (video['seconds'] as num).toDouble(),
      videoFrames: video['frames'] as int,
      segmentModel: seg['model'] as String,
      segmentPrompt: seg['prompt'] as String,
      poseMethod: recon['poses'] as String,
      reconMethod: recon['method'] as String,
      trainViews: recon['views'] as int,
      gaussians: recon['gaussians'] as int,
      psnr: (recon['psnr'] as num?)?.toDouble(),
    );
  }
}
