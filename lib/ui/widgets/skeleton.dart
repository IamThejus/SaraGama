// ui/widgets/skeleton.dart
//
// Dependency-free shimmer skeletons used in place of bare spinners, so loading
// states preview the shape of the content that's about to appear.

import 'package:flutter/material.dart';

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_ctrl.value * 2 - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFF161616),
                Color(0xFF242424),
                Color(0xFF161616),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx / bounds.width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double fraction;
  const _SlideGradient(this.fraction);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// A single shimmering rounded block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Skeleton for the 2-column home playlist grid.
class HomeGridSkeleton extends StatelessWidget {
  const HomeGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(child: SkeletonBox(height: double.infinity, radius: 14)),
            SizedBox(height: 8),
            SkeletonBox(width: 110, height: 11, radius: 4),
            SizedBox(height: 5),
            SkeletonBox(width: 60, height: 9, radius: 4),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list of rows (search / queue).
class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: const [
            SkeletonBox(width: 48, height: 48, radius: 6),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180, height: 12, radius: 4),
                  SizedBox(height: 7),
                  SkeletonBox(width: 110, height: 10, radius: 4),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
