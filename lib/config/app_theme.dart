import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  AppTheme._();

  // Core colors (from HSL CSS variables)
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF302820);
  static const Color beige = Color(0xFFF5EFE7);
  static const Color card = Color(0xFFF9F7F4);
  static const Color cardForeground = Color(0xFF302820);
  static const Color primary = Color(0xFFB5CC47);
  static const Color primaryForeground = Color(0xFF302820);
  static const Color secondary = Color(0xFFEFEBE6);
  static const Color secondaryForeground = Color(0xFF302820);
  static const Color muted = Color(0xFFE8E4DF);
  static const Color mutedForeground = Color(0xFF796F67);
  static const Color accent = Color(0xFFB5CC47);
  static const Color destructive = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color border = Color(0xFFE3DFDA);
  static const Color input = Color(0xFFE3DFDA);
  static const Color ring = Color(0xFFB5CC47);

  // Brand colors
  static const Color googleBlue = Color(0xFF4285F4);

  // Chip colors
  static const Color chipDefault = Color(0xFFAABF52);

  // Bottom nav gradient
  static const Color navGradientStart = Color(0xFFFFB5C1);
  static const Color navGradientEnd = Color(0xFFFFD5C1);

  // Tracker screen background (light blush tint of gradient)
  static const Color screenBackground = Color(0xFFF2D9DD);

  // Gut feeling colors
  static const Color gutFeelingGood = Color(0xFF40BF40);
  static const Color gutFeelingNeutral = Color(0xFFE6B800);
  static const Color gutFeelingBad = Color(0xFFD93636);

  // Shadow
  static const Color shadow = Color(0x20000000);

  // Font sizes
  static const double fontSizeXS = 9;
  static const double fontSizeSM = 11;
  static const double fontSizeCaption = 12;
  static const double fontSizeCaptionLG = 13;
  static const double fontSizeBody = 14;
  static const double fontSizeBodyLG = 15;
  static const double fontSizeSubtitle = 16;
  static const double fontSizeSubtitleLG = 17;
  static const double fontSizeTitle = 18;
  static const double fontSizeTitleLG = 20;
  static const double fontSizeHeading = 22;
  static const double fontSizeHeadingLG = 24;
  static const double fontSizeDisplay = 28;
  static const double fontSizeDisplayLG = 30;

  // Stool scale colors
  static const List<Color> stoolColors = [
    Color(0xFF1A6B37), // Type 1: HSL(142, 76%, 25%)
    Color(0xFF22904A), // Type 2: HSL(142, 76%, 35%)
    Color(0xFF32B35E), // Type 3: HSL(142, 71%, 45%)
    Color(0xFF54CC79), // Type 4: HSL(142, 69%, 55%)
    Color(0xFF6FDB8E), // Type 5: HSL(142, 71%, 65%)
  ];

  // Danger slider colors (green → yellow → red)
  static Color dangerSliderColor(double value, {int maxValue = 5}) {
    final t = (value - 1) / (maxValue - 1);
    if (t <= 0.25) {
      return Color.lerp(success, warning, t * 4)!;
    }
    return Color.lerp(warning, destructive, (t - 0.25) / 0.75)!;
  }

  static Color stoolColor(int type) {
    if (type < 1 || type > 5) return stoolColors[2];
    return stoolColors[type - 1];
  }

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: primaryForeground,
      secondary: secondary,
      onSecondary: secondaryForeground,
      surface: card,
      onSurface: foreground,
      error: destructive,
      onError: Colors.white,
      outline: border,
    ),
    fontFamily: '.SF Pro Text',
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: primaryForeground,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: fontSizeSubtitle,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: border),
        textStyle: const TextStyle(
          fontSize: fontSizeSubtitle,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontSize: fontSizeSubtitle,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ring, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: destructive),
      ),
      hintStyle: const TextStyle(color: mutedForeground),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: secondary,
      selectedColor: primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        fontSize: fontSizeBody,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
