import 'package:flutter/material.dart';

/// Skeleton hộp đơn giản dùng cho loading placeholder.
///
/// Có shimmer nhẹ để gợi cảm giác đang tải.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withOpacity(0.06);
    final highlight = theme.colorScheme.onSurface.withOpacity(0.12);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height ?? 14,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// Skeleton dạng card cho danh sách: 1 hàng tiêu đề + 2 hàng phụ.
class SkeletonListTile extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const SkeletonListTile({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 48, height: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14, width: 180),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 240),
                SizedBox(height: 6),
                SkeletonBox(height: 12, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị `count` skeleton list tile xếp dọc.
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonListTile(),
    );
  }
}
