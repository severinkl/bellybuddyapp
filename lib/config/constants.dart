import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // Spacing
  static const double spacing2 = 2.0;
  static const double spacingXs = 4.0;
  static const double spacing6 = 6.0;
  static const double spacingSm = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacingMd = 16.0;
  static const double spacing20 = 20.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Spacing widgets
  static const gap4 = SizedBox(height: 4);
  static const gap6 = SizedBox(height: 6);
  static const gap8 = SizedBox(height: 8);
  static const gap10 = SizedBox(height: 10);
  static const gap12 = SizedBox(height: 12);
  static const gap16 = SizedBox(height: 16);
  static const gap20 = SizedBox(height: 20);
  static const gap24 = SizedBox(height: 24);
  static const gap32 = SizedBox(height: 32);

  // Common padding
  static const paddingSm = EdgeInsets.all(8);
  static const paddingMd = EdgeInsets.all(16);
  static const paddingLg = EdgeInsets.all(24);

  // Icon badge sizes
  static const double iconBadgeSm = 40.0;
  static const double iconBadgeMd = 44.0;
  static const double iconBadgeLg = 48.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusIcon = 10.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusRound = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // Drag handle
  static const double dragHandleWidth = 40.0;

  // Scroll clearance (space below content to clear fixed bottom bars)
  static const double bottomBarClearance = 128.0;

  // Image sizes
  static const double mealImageHeight = 180.0;
  static const double mascotSizeMd = 96.0;

  // Divider
  static const double dividerThickness = 0.5;

  // Opacity
  static const double disabledOpacity = 0.4;

  // Spinner
  static const double spinnerSize = 20.0;

  // External URLs
  static const String feedbackFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSfHqqGW_159yd_sUacBZq5aITZwGDikag_lgd8eudHQcelNGA/viewform?usp=dialog';

  // SharedPreferences keys
  static const String keyNotificationModalShown = 'notification_modal_shown';

  // Icon sizes
  static const double iconSizeSm = 18.0;

  // Button
  static const double buttonHeight = 56.0;

  // Bottom nav
  static const double bottomNavCenterButtonSize = 80.0;

  // Durations
  static const Duration pressScaleDuration = Duration(milliseconds: 100);
  static const Duration successOverlayDuration = Duration(milliseconds: 1500);
  static const Duration autoAdvanceDuration = Duration(seconds: 4);
  static const Duration debounceDuration = Duration(milliseconds: 800);

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animSlower = Duration(milliseconds: 600);

  // Asset paths
  static const String mascotBasePath = 'assets/images/mascot';
  static const String imagesBasePath = 'assets/images';
  static const String iconsBasePath = 'assets/images/icons';

  // Mascot images
  static const String mascotHappy = '$mascotBasePath/mascot-happy.png';
  static const String mascotCool = '$mascotBasePath/mascot-cool.png';
  static const String mascotProfessor = '$mascotBasePath/mascot-professor.png';
  static const String mascotWink = '$mascotBasePath/mascot-wink.png';
  static const String mascotEnergetic = '$mascotBasePath/mascot-energetic.png';
  static const String mascotNervous = '$mascotBasePath/mascot-nervous.png';
  static const String mascotClueless = '$mascotBasePath/mascot-clueless.png';
  static const String mascotSad = '$mascotBasePath/mascot-sad.png';
  static const String mascotBored = '$mascotBasePath/mascot-bored.png';
  static const String mascotClear = '$mascotBasePath/mascot-clear.png';
  static const String mascotUnfocused = '$mascotBasePath/mascot-unfocused.png';
  static const String mascotStressed = '$mascotBasePath/mascot-stressed.png';
  static const String mascotInLove = '$mascotBasePath/mascot-in-love.png';
  static const String mascotZen = '$mascotBasePath/mascot-zen.png';
  static const String mascotBloatingStomach =
      '$mascotBasePath/mascot-bloating-stomach.png';
  static const String mascotHappyStomach =
      '$mascotBasePath/mascot-happy-stomach.png';
  static const String mascotFlatulance =
      '$mascotBasePath/mascot-flatulance.png';
  static const String mascotCramp = '$mascotBasePath/mascot-cramp.png';
  static const String mascotNoCramp = '$mascotBasePath/mascot-no-cramp.png';
  static const String mascotFullness = '$mascotBasePath/mascot-fullness.png';

  // Other images
  static const String susiPhone = '$imagesBasePath/susi-phone.png';
  static const String fuerDichCard = '$imagesBasePath/fuer-dich-card.png';
  static const String alternativenCard =
      '$imagesBasePath/alternativen-card.jpg';
  static const String rezepteCard = '$imagesBasePath/rezepte-card.jpg';
  static const String logoSvg = '$imagesBasePath/logo.svg';
  static const String toiletPaperIcon = '$iconsBasePath/toilet-paper-icon.png';
  static const String toiletPaperSvg = '$iconsBasePath/toilet-paper-3.svg';

  // Stool type descriptions
  static const Map<int, String> stoolTypeDescriptions = {
    1: 'Sehr hart',
    2: 'Hart',
    3: 'Normal',
    4: 'Weich',
    5: 'Flüssig',
  };

  // Intolerance options (used in registration + settings)
  static const List<String> intoleranceOptions = [
    'Laktose',
    'Gluten',
    'Fruktose',
    'Histamin',
    'Sorbit',
    'Nüsse',
    'Eier',
    'Soja',
    'Weizen',
  ];

  // Symptom options (used in registration + settings)
  static const List<String> symptomOptions = [
    'Blähungen',
    'Bauchschmerzen',
    'Durchfall',
    'Verstopfung',
    'Übelkeit',
    'Sodbrennen',
    'Krämpfe',
    'Völlegefühl',
  ];

  // Drink sizes
  static const List<int> drinkSizes = [250, 330, 500, 1000];

  // Gut feeling symptom labels
  static const List<String> gutFeelingSymptoms = [
    'Blähbauch',
    'Blähungen',
    'Krämpfe',
    'Völlegefühl',
  ];

  // Stimmung (mood) labels
  static const List<String> stimmungLabels = [
    'gestresst',
    'traurig',
    'müde',
    'unkonzentriert',
    'unwohl',
  ];
}
