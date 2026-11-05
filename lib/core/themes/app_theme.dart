import 'package:flutter/material.dart';
import 'package:glide/core/constants/app_constants.dart';

/// Light, dark and high-contrast themes. All of them enforce large touch
/// targets and readable text sizes so screens don't have to.
abstract final class AppTheme {
  static ThemeData get light =>
      _build(ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FFF)));

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5FFF),
      brightness: Brightness.dark,
    ),
  );

  /// Yellow on black: the combination most low-vision users prefer, with a
  /// contrast ratio well above WCAG AAA.
  static ThemeData get highContrast => _build(
    const ColorScheme.dark(
      primary: Color(0xFFFFE600),
      onPrimary: Colors.black,
      secondary: Colors.white,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Color(0xFFFFE600),
      error: Color(0xFFFF6E6E),
      onError: Colors.black,
    ),
    borderSide: const BorderSide(color: Color(0xFFFFE600), width: 2),
  );

  static ThemeData _build(ColorScheme scheme, {BorderSide? borderSide}) {
    const minSize = Size(
      AppConstants.minTouchTarget,
      AppConstants.minTouchTarget,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: Typography.material2021().englishLike.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          side: borderSide,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minSize),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }
}
