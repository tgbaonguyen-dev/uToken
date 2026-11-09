import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Nền chính của toàn app và màn hình (Figma spec: #090A0B)
  static const Color background = Color(0xFF090A0B);

  /// Nền các Card / Surface (Figma spec: #121519)
  static const Color surface = Color(0xFF121519);

  /// Viền Card / Surface (Figma spec: #2A2F36)
  static const Color surfaceBorder = Color(0xFF2A2F36);

  /// Màu Icon trong Card Info (Figma spec)
  static const Color iconPrimaryBorder = Color(0xFF6678E8);
  static const Color iconTextLines = Color(0xFF9AA7FF);

  /// Màu Icon trong Card Cancelled / Neutral (Figma spec: EmptyInbox)
  static const Color iconNeutralBorder = Color(0xFF737985);
  static const Color iconNeutralRays = Color(0xFFAEB4BF);

  /// Nút bấm Primary / Bottom Action
  static const Color buttonBg = Color(0xFFF4F4F5);
  static const Color buttonText = Color(0xFF111214);

  /// Text colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF989FA8);
  static const Color textMuted = Color(0xFF6E6E73);
  static const Color textStateLabel = Color(0xFF92929A);

  /// Chấm tròn bullet points (Figma State Surface)
  static const Color bulletBlue = Color(0xFF6678E8);
  static const Color bulletGray = Color(0xFF7B7F88);
  static const Color bulletWarning = Color(0xFFC27A20);
  static const Color bulletRed = Color(0xFFE0525B);
  static const Color bulletGreen = Color(0xFF22A575);

  /// Back glyph (Figma: #6E6E73, Size 28px)
  static const Color backGlyph = Color(0xFF6E6E73);

  /// Bottom dock divider (Figma spec: #252A31, Height 1px)
  static const Color dockDivider = Color(0xFF252A31);

  /// Bottom navigation surface (Figma spec: #0C0F13, Height 68px)
  static const Color navSurface = Color(0xFF0C0F13);

  /// Bottom navigation tab items
  static const Color navActive = Color(0xFFF2F3F5);
  static const Color navInactive = Color(0xFF7B818A);
}
