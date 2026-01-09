import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trailzap/utils/constants.dart';

class GradientButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        if (!isDisabled) {
          HapticFeedback.lightImpact();
          widget.onPressed?.call();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.6 : 1.0,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: widget.gradient ?? AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: (widget.gradient?.colors.first ?? AppColors.primaryGreen)
                      .withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : DefaultTextStyle(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        child: widget.child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined gradient button variant
class GradientOutlineButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;
  final double borderWidth;

  const GradientOutlineButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gradient,
    this.height = 56,
    this.borderRadius = 16,
    this.borderWidth = 2,
  });

  @override
  State<GradientOutlineButton> createState() => _GradientOutlineButtonState();
}

class _GradientOutlineButtonState extends State<GradientOutlineButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppColors.accentGradient;
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (!isDisabled) {
          HapticFeedback.lightImpact();
          widget.onPressed?.call();
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.5 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.97 : 1.0,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: gradient,
            ),
            padding: EdgeInsets.all(widget.borderWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(
                  widget.borderRadius - widget.borderWidth,
                ),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => gradient.createShader(bounds),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon button with gradient
class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final LinearGradient? gradient;

  const GradientIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 48,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onPressed != null) {
          HapticFeedback.lightImpact();
          onPressed?.call();
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(size / 3),
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.first ?? AppColors.primaryGreen)
                  .withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}
