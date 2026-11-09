import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  /// Font chính của toàn app là Be Vietnam Pro theo chuẩn Figma
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Tiêu đề màn hình (Figma spec: Be Vietnam Pro, 22px, SemiBold 600, Line height 30px, Color #F4F4F5, Top 52px)
  static TextStyle screenTitle = GoogleFonts.beVietnamPro(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFF4F4F5),
    height: 30 / 22,
    letterSpacing: 0,
  );

  /// Nhãn trạng thái góc phải (Figma spec: Be Vietnam Pro, 10px, SemiBold 600, Line height 16px, Color #92929A, Top 28px, Align Right)
  static TextStyle stateLabel = GoogleFonts.beVietnamPro(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textStateLabel,
    height: 16 / 10,
    letterSpacing: 0,
  );

  /// Phụ đề trạng thái (Figma spec: Be Vietnam Pro, 11px, Medium 500, Line height 18px, Color #8E8E73, Top 94px)
  static TextStyle stateContext = GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 18 / 11,
    letterSpacing: 0,
  );

  /// Tiêu đề Card (Figma spec: Be Vietnam Pro, 16px, SemiBold 600, Line height 22px, Color #F4F4F5)
  static TextStyle cardTitle = GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFF4F4F5),
    height: 22 / 16,
    letterSpacing: 0,
  );

  /// Mô tả Card (Figma spec: Be Vietnam Pro, 12px, Regular 400, Line height 18px, Color #989FA8)
  static TextStyle cardDescription = GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF989FA8),
    height: 18 / 12,
    letterSpacing: 0,
  );

  /// Tiêu đề Bullet item (Figma spec: Be Vietnam Pro, 12px, Medium 500, Line height 20px, Color #F4F4F5)
  static TextStyle bulletTitle = GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: const Color(0xFFF4F4F5),
    height: 20 / 12,
    letterSpacing: 0,
  );

  /// Phụ đề Bullet item / Detail meta (Figma spec: Be Vietnam Pro, 10px, Regular 400, Line height 16px, Color #989FA8)
  static TextStyle bulletSubtitle = GoogleFonts.beVietnamPro(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF989FA8),
    height: 16 / 10,
    letterSpacing: 0,
  );

  /// Nhãn BEHAVIOR
  static TextStyle behaviorLabel = GoogleFonts.beVietnamPro(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 16 / 10,
    letterSpacing: 0,
  );

  /// Nội dung mô tả BEHAVIOR (Figma spec: Be Vietnam Pro, 12px, Regular 400, Line height 20px, Color #8E8E73)
  static TextStyle behaviorText = GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 20 / 12,
    letterSpacing: 0,
  );

  /// Chữ trên Nút bấm (Button label: Cancel, Try again, Retry sign-in)
  static TextStyle buttonLabel = GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.buttonText,
    height: 20 / 13,
    letterSpacing: 0,
  );
}

