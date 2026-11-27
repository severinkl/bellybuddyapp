import 'package:material_ui/material_ui.dart';
import 'constants.dart';

class AppTheme {
  AppTheme._();

  // Core colors (from HSL CSS variables)
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF302820);

  /// A placeholder's glyph or monogram on its pastel: [foreground] at 45 %.
  static const Color placeholderGlyph = Color.from(
    alpha: 0.45,
    red: 0x30 / 255,
    green: 0x28 / 255,
    blue: 0x20 / 255,
  );
  static const Color beige = Color(0xFFF5EFE7);
  static const Color card = Color(0xFFF9F7F4);
  static const Color cardForeground = Color(0xFF302820);
  static const Color primary = Color(0xFFB5CC47);
  static const Color primaryForeground = Color(0xFF302820);

  /// Secondary text on [primary] (hints): 5:1 on it, where a faded
  /// [primaryForeground] fell to 3:1.
  static const Color primaryForegroundMuted = Color(0xFF4B4928);
  static const Color secondary = Color(0xFFEFEBE6);
  static const Color secondaryForeground = Color(0xFF302820);
  static const Color muted = Color(0xFFE8E4DF);
  static const Color mutedForeground = Color(0xFF675E57);
  static const Color accent = Color(0xFFB5CC47);
  static const Color destructive = Color(0xFFC62828);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  /// Text-safe variants (4.5:1) of the brand fills; the fills keep their
  /// own tokens for backgrounds and decorative icons.
  static const Color primaryText = Color(0xFF56631A);
  static const Color successText = Color(0xFF1F6B1F);
  static const Color infoText = Color(0xFF1D4ED8);

  /// The „Passt für mich" check on an alternative's picture (3:1 on its
  /// white disc).
  static const Color alternativeFitsCheck = successText;

  /// The „Aktiv" state word of a share (dark enough for text on [card]).
  static const Color shareActive = successText;

  /// „Genauer hingeschaut"'s „deutlich auffällig" badge: light text on the
  /// dark fill (the other levels use [muted]/[card] with dark text).
  static const Color statBadgeStrongFill = foreground;
  static const Color statBadgeStrongText = background;
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

  /// Inactive bar icons, labels and tab text: [foreground] at 75 %.
  static const Color foregroundInactive = Color.from(
    alpha: 0.75,
    red: 0x30 / 255,
    green: 0x28 / 255,
    blue: 0x20 / 255,
  );

  /// Fill of the „Neu" pill (white text on it).
  static const Color badgeFill = Color(0xFFC8325A);

  /// The dot on a bottom-bar tab that holds news.
  static const Color navBadge = Color(0xFFE8456F);

  // Tracker screen background (light blush tint of gradient)
  static const Color screenBackground = Color(0xFFF2D9DD);

  // Gut feeling colors
  static const Color gutFeelingGood = Color(0xFF40BF40);
  static const Color gutFeelingNeutral = Color(0xFFE6B800);
  static const Color gutFeelingBad = Color(0xFFD93636);

  // Muster calendar: a day's cell, a light tint of its class's colour
  // above, and the class's icon (in the cells, the legend and the day
  // cards): darker shades with at least 3:1 on the tint, the page and the
  // card (WCAG 1.4.11; schwer's colour already has it)
  static const Color gutFeelingGoodSoft = Color(0xFFE5F5E5);
  static const Color gutFeelingNeutralSoft = Color(0xFFFCF4D6);
  static const Color gutFeelingBadSoft = Color(0xFFF9E1E1);
  static const Color gutFeelingGoodText = successText;
  static const Color gutFeelingNeutralText = Color(0xFF7A5F00);
  static const Color gutFeelingGoodIcon = Color(0xFF2E8B2E);
  static const Color gutFeelingNeutralIcon = Color(0xFF9A7A00);
  static const Color gutFeelingBadIcon = gutFeelingBad;

  // Buddy mascot colors
  static const Color buddyOutline = Color(0xFF0D0D0F);
  static const Color buddyBody = Color(0xFFFFABB6);
  static const Color buddyTongue = Color(0xFFE8456F);
  static const Color buddyBlush = Color(0xFFFF7F95);
  static const Color buddySparkle = Color(0xFFFFC83D);
  static const Color buddyHeart = Color(0xFFE8456F);
  static const Color buddyWater = Color(0xFF6EC6F0);
  static const Color buddyFood = Color(0xFFB5CC47);
  static const Color buddyFoodLeaf = Color(0xFF6E8B2A);
  static const Color buddyShadow = Color(0x140D0D0F);

  // Streak: a day with an entry (week row circle), the selected goal
  static const Color primarySoft = Color(0xFFF3F7DF);

  // Belly Buddy Plus: the „Plus" badge on a button that needs it (on the
  // tonal button's light green)
  static const Color plusBadge = Color(0xFF302820);
  static const Color plusBadgeForeground = Color(0xFFF9F7F4);

  // Rezepte: the illustration background per meal type (the placeholder of a
  // recipe without a photo), and the mark of a step the Buddy changed
  static const Color recipeTintBreakfast = Color(0xFFFCF1CF);
  static const Color recipeTintLunch = Color(0xFFEEF4D2);
  static const Color recipeTintDinner = Color(0xFFFBE6CF);
  static const Color recipeTintSnack = Color(0xFFF3EADF);
  static const Color recipeTintOther = Color(0xFFEAD9CB);
  static const Color recipeChanged = Color(0xFFE2EDA9);

  // Care: one color and one soft tint per need (Essen, Trinken, Bauchgefühl,
  // Klo), each at least 3:1 on the page, and the glow around the need he
  // suggests next. The streak flame burns red at its tips, orange in its
  // middle and yellow at its base, around a bright core (and a blazing
  // flame's hot one) in a warm glow; an ember (its colour, its core) waits
  // for today's first entry, darker and warmer on the primary colour (the
  // success page), where the pale one would not show (its body at least
  // 3:1 there).
  static const Color careFood = Color(0xFFD27A12);
  static const Color careFoodSoft = Color(0xFFFCEBD5);
  static const Color careWater = Color(0xFF3A8FCC);
  static const Color careWaterSoft = Color(0xFFE2F0FA);
  static const Color careGut = Color(0xFF3A9A48);
  static const Color careGutSoft = gutFeelingGoodSoft;
  static const Color progressTrendBar = primary;
  static const Color careLoo = Color(0xFF9C7350);
  static const Color careLooSoft = Color(0xFFF1E7DE);
  static const Color streakFlame = Color(0xFFFF7A2E);
  static const Color streakFlameRed = Color(0xFFE5391F);
  static const Color streakFlameCore = buddySparkle;
  static const Color streakFlameBright = Color(0xFFFFF1B8);
  static const Color streakFlameHot = buddyWater;
  static const Color streakFlameGlow = Color(0x66FF8C3C);
  static const Color streakEmber = Color(0xFFF4B996);
  static const Color streakEmberCore = Color(0xFFF8DDA6);
  static const Color streakEmberOnPrimary = Color(0xFFA8431A);
  static const Color streakEmberCoreOnPrimary = Color(0xFFD2601F);
  static const Color careGlow = Color(0x4DB5CC47);

  // Notification previews (the reminder step): an iOS banner's colors
  static const Color notificationCard = Color(0xFFEFEFF4);
  static const Color notificationForeground = Color(0xFF1C1C1E);
  static const Color notificationMuted = Color(0xFF6C6C70);

  // Shadow
  static const Color shadow = Color(0x20000000);

  // Scrim (~55% black) — used behind modals/overlays to dim the background
  static const Color scrim = Color(0x8C000000);

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

  /// Letter spacing of a share code shown in [fontSizeDisplayLG], so its
  /// two groups of digits read apart.
  static const double codeLetterSpacing = 2;

  // Line heights (multiples of the font size)
  /// Running text: notes, summaries, explanations.
  static const double lineHeightBody = 1.4;

  /// Short, dense text: headlines over two lines, speech and tour bubbles,
  /// previews.
  static const double lineHeightSnug = 1.35;

  // Named text styles
  /// Short body text in lists and cards (a column's items, „Fällt mir
  /// auf"'s rows).
  static const TextStyle bodyStyle = TextStyle(
    fontSize: fontSizeBody,
    height: lineHeightSnug,
    color: foreground,
  );

  /// [bodyStyle], muted: labels, empty states, uncertain rows.
  static const TextStyle bodyMutedStyle = TextStyle(
    fontSize: fontSizeBody,
    height: lineHeightSnug,
    color: mutedForeground,
  );

  /// Small muted text: a caption, a tile's meta line, a switch's
  /// explanation.
  static const TextStyle captionMutedStyle = TextStyle(
    fontSize: fontSizeCaptionLG,
    color: mutedForeground,
  );

  // The streak moment's big count („1 Tag" beside the flame)
  static const double fontSizeStreakCount = 56;

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
        foregroundColor: primaryText,
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
      // Without a color the label is painted white on the light chip.
      labelStyle: const TextStyle(
        color: foreground,
        fontSize: fontSizeBody,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
