import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Nút bấm Primary dùng chung chuẩn theo Figma:
/// - Kích thước: Width: 350 (margin 20px 2 bên), Height: 52px
/// - Bo góc: 14px
/// - Nền: #F4F4F5
/// - Font: Be Vietnam Pro 13px SemiBold #111214
/// - Shadow: Y=2, Blur=6, Color=Black 24%
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 52.0,
    this.borderRadius = 14.0,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000), // Black 24%
            offset: Offset(0, 2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Semantics(
          button: true,
          enabled: onPressed != null,
          child: Material(
            color: backgroundColor ?? AppColors.buttonBg,
            borderRadius: BorderRadius.circular(borderRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Text(
                  label,
                  style: textColor != null
                      ? AppTypography.buttonLabel.copyWith(color: textColor)
                      : AppTypography.buttonLabel,
                ),
              ),
            ),
          )),
    );
  }
}
