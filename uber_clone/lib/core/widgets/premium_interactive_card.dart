import 'package:flutter/material.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';

class PremiumInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double opacity;
  final double blur;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PremiumInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.opacity = 0.15,
    this.blur = 15.0,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  @override
  State<PremiumInteractiveCard> createState() => _PremiumInteractiveCardState();
}

class _PremiumInteractiveCardState extends State<PremiumInteractiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) => _controller.forward();
  void _handleTapUp(TapUpDetails details) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: PremiumGlassContainer(
            color: widget.color,
            opacity: widget.opacity,
            blur: widget.blur,
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            margin: widget.margin,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
