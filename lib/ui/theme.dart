import 'package:flutter/material.dart';

abstract final class Palette {
  static const ink = Color(0xFF303C40);
  static const muted = Color(0xFF82908E);
  static const mint = Color(0xFF5A9E8C);
  static const mintLight = Color(0xFFDDF1E8);
  static const lavender = Color(0xFF9C8AC4);
  static const lavenderLight = Color(0xFFECE5F7);
  static const peach = Color(0xFFE5A88D);
  static const peachLight = Color(0xFFFFEBDD);
  static const sky = Color(0xFF87ABC1);
  static const skyLight = Color(0xFFE4EFF6);
  static const rose = Color(0xFFCF7F90);
  static const line = Color(0xFFE6EAE5);
}

ThemeData studyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.mint,
      surface: const Color(0xFFF7F9F5),
    ),
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'NotoSansSC',
    fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC', 'sans-serif'],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: Palette.line,
      space: 1,
      thickness: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Palette.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.mint, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.mint
            : const Color(0xFFDBE2DE),
      ),
    ),
  );
}
