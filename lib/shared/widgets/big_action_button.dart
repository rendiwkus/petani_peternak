import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Tombol aksi utama ramah jari (tinggi 56dp) dengan state loading/disabled.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppTheme.primaryGreen,
    this.foregroundColor = Colors.white,
    this.isLoading = false,
    this.isOutlined = false,
    this.expand = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;
  final bool isOutlined;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        else
          Icon(icon, size: 24),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            isLoading ? 'Memproses...' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final onTap = disabled
        ? null
        : () {
            HapticFeedback.mediumImpact();
            onPressed?.call();
          };

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 120, AppTheme.buttonHeight),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (disabled) return AppTheme.disabledBg;
        if (states.contains(WidgetState.pressed)) {
          return backgroundColor.withValues(alpha: 0.82);
        }
        return isOutlined ? Colors.transparent : backgroundColor;
      }),
      foregroundColor: WidgetStatePropertyAll(
        disabled
            ? AppTheme.disabledFg
            : (isOutlined ? backgroundColor : foregroundColor),
      ),
      overlayColor: WidgetStatePropertyAll(
        backgroundColor.withValues(alpha: 0.12),
      ),
      side: isOutlined
          ? WidgetStatePropertyAll(
              BorderSide(
                color: disabled ? AppTheme.disabledBg : backgroundColor,
                width: 1.5,
              ),
            )
          : null,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: style,
        child: child,
      );
    }
    return FilledButton(
      onPressed: onTap,
      style: style,
      child: child,
    );
  }
}
