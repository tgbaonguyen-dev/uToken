import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'ut_kit.dart';

/// App theme shared by production screens.
ThemeData buildAppTheme() => ThemeData(
    fontFamily: 'BeVietnamPro',
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: UtColors.background,
    colorScheme: const ColorScheme.dark(
      surface: UtColors.card,
      primary: UtColors.text,
      onPrimary: UtColors.primaryButtonText,
      secondary: UtColors.orange,
      error: Color(0xFFE0525B),
      outline: UtColors.cardBorder,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: UtColors.card,
      titleTextStyle: UtText.title,
      contentTextStyle: UtText.body.copyWith(fontSize: 14, height: 1.5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: UtColors.cardBorder)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: UtColors.card, showDragHandle: true),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: UtColors.chip,
      contentTextStyle: const TextStyle(
          fontFamily: 'BeVietnamPro', fontSize: 13, color: UtColors.text),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: UtColors.cardBorder)),
    ),
    // Android-sized tap targets (48dp) everywhere.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Detail screens slide in from the right with swipe-back, the same
    // on every platform; tabs use their own cross-fade (see router).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    splashFactory: InkRipple.splashFactory);
