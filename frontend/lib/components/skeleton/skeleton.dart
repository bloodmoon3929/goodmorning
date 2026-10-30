import 'package:flutter/material.dart';

import '../../core/network/load_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 스켈레톤 로딩 (docs/03-tech-spec.md 34번): 화면 모양 그대로 회색 틀을 먼저 보여 주고,
/// 빛이 지나가는 효과로 "불러오는 중"임을 보인다. 빈 화면 + 빙글빙글은 쓰지 않는다.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Color(0xFFEDEFF2), Color(0xFFF8F9FA), Color(0xFFEDEFF2)],
        stops: const [0.25, 0.5, 0.75],
        begin: const Alignment(-1.0, -0.3),
        end: const Alignment(1.0, 0.3),
        transform: _Slide(_c.value),
      ).createShader(bounds),
      child: child,
    ),
  );
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// 회색 상자 하나
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFEDEFF2),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// 상품 카드 모양 (2열)
class SkeletonProductGrid extends StatelessWidget {
  const SkeletonProductGrid({super.key, this.rows = 1});
  final int rows;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(aspectRatio: 1.55, child: SkeletonBox(height: double.infinity, radius: 14)),
                          SizedBox(height: 10),
                          SkeletonBox(width: 70, height: 10),
                          SizedBox(height: 8),
                          SkeletonBox(width: 130, height: 14),
                          SizedBox(height: 10),
                          SkeletonBox(width: 110, height: 20, radius: 10),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// 목록 한 줄 모양 (사진 + 글 두세 줄)
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 4, this.thumb = 72});
  final int count;
  final double thumb;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppGap.page, 8, AppGap.page, 12),
            child: Row(
              children: [
                SkeletonBox(width: thumb, height: thumb, radius: 12),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 80, height: 10),
                      SizedBox(height: 8),
                      SkeletonBox(height: 14),
                      SizedBox(height: 10),
                      SkeletonBox(width: 120, height: 20, radius: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 가로 타일 줄 (내 IP · 캐릭터)
class SkeletonTiles extends StatelessWidget {
  const SkeletonTiles({super.key, this.count = 5, this.size = 58, this.circle = false});
  final int count;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) => Shimmer(
    // 실제 타일 줄(가로 스크롤)처럼 화면 끝에서 잘린다
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  SkeletonBox(width: size, height: size, radius: 16, circle: circle),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 40, height: 10),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// 카드 상자 모양 (매장 카드 등)
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({super.key, this.count = 2, this.height = 100, this.horizontal = true});
  final int count;
  final double height;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final boxes = [for (var i = 0; i < count; i++) SkeletonBox(height: height, radius: 14)];
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
        child: horizontal
            ? Row(
                children: [
                  for (var i = 0; i < count; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: boxes[i])],
                ],
              )
            : Column(
                children: [
                  for (var i = 0; i < count; i++) ...[if (i > 0) const SizedBox(height: 12), boxes[i]],
                ],
              ),
      ),
    );
  }
}

/// 컴포넌트 하나의 부분 로딩: 데이터가 오기 전에는 [skeleton], 오면 [builder], 실패하면 다시 시도.
class LoadView<T> extends StatelessWidget {
  const LoadView({super.key, required this.load, required this.skeleton, required this.builder, this.onRetry});

  final Load<T> load;
  final Widget skeleton;
  final Widget Function(T value) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final child = switch (load) {
      Loading<T>() => KeyedSubtree(key: const ValueKey('loading'), child: skeleton),
      Loaded<T>(:final value) => KeyedSubtree(key: const ValueKey('loaded'), child: builder(value)),
      LoadFailed<T>() => Padding(
        key: const ValueKey('failed'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Text('불러오지 못했어요', style: TextStyle(color: AppColors.sub)),
            ),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: child,
    );
  }
}
