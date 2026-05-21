import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum MantraButtonVariant { primary, secondary, outline, ghost }

class MantraButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final MantraButtonVariant variant;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const MantraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = MantraButtonVariant.primary,
    this.width,
    this.height = 52,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<MantraButton> createState() => _MantraButtonState();
}

class _MantraButtonState extends State<MantraButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    switch (widget.variant) {
      case MantraButtonVariant.primary:
        return AppColors.primary;
      case MantraButtonVariant.secondary:
        return AppColors.secondary;
      case MantraButtonVariant.outline:
        return Colors.transparent;
      case MantraButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    if (widget.foregroundColor != null) return widget.foregroundColor!;
    switch (widget.variant) {
      case MantraButtonVariant.primary:
        return Colors.white;
      case MantraButtonVariant.secondary:
        return Colors.white;
      case MantraButtonVariant.outline:
        return AppColors.primary;
      case MantraButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null && !widget.isLoading;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) {
          if (!isDisabled) {
            HapticFeedback.lightImpact();
            _scaleController.forward();
          }
        },
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: isDisabled
                ? _backgroundColor.withOpacity(0.4)
                : _backgroundColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: widget.variant == MantraButtonVariant.outline
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: widget.variant == MantraButtonVariant.primary &&
                    !isDisabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_foregroundColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: _foregroundColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (widget.icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          widget.icon,
                          color: _foregroundColor,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
