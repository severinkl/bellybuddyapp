import 'package:material_ui/material_ui.dart';

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

  /// The scroll padding of a text field with a hint line under it: below
  /// the caret it scrolls the field's bottom, the hint and a margin clear
  /// of the keyboard (the default 20 can leave the hint cut off).
  static const EdgeInsets fieldWithHintScrollPadding = EdgeInsets.fromLTRB(
    spacing20,
    spacing20,
    spacing20,
    72,
  );

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
  static const double iconBadgeXs = 32.0;
  static const double iconBadgeSm = 40.0;
  static const double iconBadgeMd = 44.0;
  static const double iconBadgeLg = 48.0;
  static const double iconBadgeXl = 56.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusIcon = 10.0;
  static const double radiusMd = 12.0;
  static const double radiusPill = 14.0;
  static const double radiusLg = 16.0;
  static const double radiusRound = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // Border widths
  static const double borderWidthSm = 0.5;
  static const double borderWidthMd = 1.5;
  static const double borderWidthLg = 2.0;

  // Drag handle
  static const double dragHandleWidth = 40.0;
  static const double dragHandleHeight = 4.0;
  static const double dragHandleRadius = 2.0;

  // Buddy speech bubble (comic style): the slot above the Buddy (two lines
  // plus tail and shadow), the bubble's widest width and its line limit
  static const double buddyBubbleHeight = 76.0;
  static const double buddyBubbleMaxWidth = 280.0;
  static const int buddyBubbleMaxLines = 4;

  // Its tail (base width, length), the side tail's middle below the
  // bubble's top, and the flat shadow's offset
  static const double buddyBubbleTailBase = 24.0;
  static const double buddyBubbleTailLength = 12.0;
  static const double buddyBubbleSideTailTop = 34.0;
  static const Offset buddyBubbleShadowOffset = Offset(3, 4);

  // Typewriter reveal: per character, at most this long in total
  static const Duration buddyBubbleCharDelay = Duration(milliseconds: 30);
  static const Duration buddyBubbleTypeMax = Duration(milliseconds: 1200);

  // Streak chip / goal sheet
  static const double streakChipPopScale = 1.25;
  static const double streakSheetBuddyHeight = 220.0;

  // Streak week row (Mo–So): day circle
  static const double streakWeekDaySize = 36.0;

  // A streak goal's row in the goal list
  static const double streakGoalRowHeight = 56.0;

  // The Eintragen sheet's option height; the diary's empty-day Buddy
  static const double logSheetOptionHeight = 96.0;
  static const double diaryEmptyBuddySize = 96.0;

  // Reminder step: the notification preview's corner radius and app icon,
  // the example week's label column and dots
  static const double notificationPreviewRadius = 20.0;
  static const double notificationPreviewIconSize = 22.0;
  static const double reminderExampleLabelWidth = 112.0;
  static const double reminderExampleDotSize = 16.0;

  /// Need meters (tunable): how long awake time drains each need from full,
  /// the night pause (local hours) in which nothing drains, and the levels.
  /// The floor keeps a meter from ever looking empty; low and high split the
  /// meter's mood colours.
  static const Duration careFoodDrain = Duration(hours: 5);
  static const Duration careDrinkDrain = Duration(hours: 3);
  static const Duration careGutFeelingDrain = Duration(hours: 24);
  static const int careNightFromHour = 22;
  static const int careNightUntilHour = 7;
  static const double careMeterFloor = 0.15;
  static const double careMeterLow = 0.35;
  static const double careMeterHigh = 0.7;

  /// A need meter's ring thickness, as a share of its diameter.
  static const double careMeterStrokeShare = 0.085;

  // Dashboard care ring: its diameter (at most this, this share of the
  // width and of the screen height, at least the minimum), stroke, the gap
  // between its four segments, and the Buddy's box inside it
  static const double careRingMaxDiameter = 260.0;
  static const double careRingMinDiameter = 170.0;
  static const double careRingWidthFactor = 0.72;
  static const double careRingHeightFactor = 0.3;
  static const double careRingStroke = 13.0;
  static const double careRingGapDegrees = 6.0;
  static const double careRingBuddyFactor = 0.74;

  // Its need bubbles (Essen n/3 …): size, the next need's glow (also the
  // margin of each bubble's tap area, so it must reach past the shadow's
  // offset), its pulse
  static const double careNeedWidth = 88.0;
  static const double careNeedMinHeight = 62.0;
  static const double careNeedGlow = 5.0;
  static const Offset careNeedShadowOffset = Offset(0, 3);
  static const Duration careNeedPulse = Duration(milliseconds: 1400);

  // „Dein Streak" sheet: the goal progress bar
  static const double streakProgressHeight = 10.0;

  // Home's insight card: its progress bars
  static const double insightProgressHeight = 7.0;

  // Muster page: how blurred the locked state's sample preview is
  static const double patternsPreviewBlur = 5.0;

  // Entdecken: a recipe card's width in the Meine Rezepte row
  static const double discoverRecipeCardWidth = 148.0;

  // Wissen: an article's square thumbnail
  static const double knowledgeThumbSize = 64.0;

  // Ich: the Buddy in the header
  static const double meBuddySize = 112.0;

  // Buddy reaction on the tracker success screens (bubble slot + Buddy)
  static const double buddyReactionSize = 220.0;

  // Buddy onboarding (/buddy-onboarding): stage (bubble slot + Buddy) and
  // progress dots
  static const double buddyOnboardingStageHeight = 240.0;
  // … and on steps with little content below him (intro, first meal,
  // streak moment) a bigger one
  static const double buddyOnboardingHeroStageHeight = 340.0;
  // … and on steps with nothing below him (intro, first meal) he grows into
  // the free height up to this, centred in it
  static const double buddyOnboardingHeroStageMaxHeight = 460.0;
  static const double progressDotSize = 8.0;
  static const double progressDotActiveWidth = 24.0;

  // Registration wizard: above every step a header with the Buddy on the
  // left (this wide; his height follows) and his bubble on the right; with
  // the keyboard open a compact header (the Buddy this tall). Below it a
  // step keeps at least the min height (on shorter screens the host
  // scrolls instead). The min height leaves a 393×852 phone with the
  // keyboard open a fixed header: a field scrolled into view never pushes
  // the Buddy's bubble off the top.
  static const double buddyWizardBuddyWidth = 124.0;
  static const double buddyWizardCompactSize = 72.0;
  static const double buddyWizardCompactHeaderHeight = 100.0;
  static const double buddyWizardMinStepHeight = 220.0;

  // Padding of a wizard step below the header
  static const wizardStepPadding = EdgeInsets.fromLTRB(
    spacingLg,
    spacingSm,
    spacingLg,
    spacingMd,
  );

  // Scroll clearance (space below content to clear fixed bottom bars)
  static const double bottomBarClearance = 128.0;

  // Image sizes
  static const double mealImageHeight = 180.0;
  static const double mascotSizeMd = 96.0;
  static const double mascotSizeLg = 160.0;

  // Divider
  static const double dividerThickness = 0.5;

  // Opacity
  static const double disabledOpacity = 0.4;

  // Spinner
  static const double spinnerSize = 20.0;

  // Recommendation dislike comment — cap to keep DB rows sane; the label
  // counter doubles as a visible limit so the user isn't surprised.
  static const int dislikeCommentMaxLength = 1000;

  // External URLs
  static const String feedbackFormUrl =
      'https://us20.list-manage.com/survey?u=526bdf1360ec4bf225504e006&id=d47032793c&attribution=false';

  /// Where the password-reset email link lands: the reset-password page of the
  /// Belly Buddy web app, where the user sets the new password.
  static const String resetPasswordRedirectUrl =
      'https://app.bellybuddy.at/reset-password';

  /// Public privacy policy (Datenschutzerklärung) of the Belly Buddy web app.
  static const String privacyPolicyUrl =
      'https://app.bellybuddy.at/datenschutz';

  /// Version of the privacy policy the health-data consent refers to. Bump it
  /// when the policy changes materially: every user whose stored
  /// `profiles.privacy_policy_version` differs is sent through the consent
  /// gate again.
  static const String privacyPolicyVersion = '2026-11-22';

  /// The myfodmap blog feed behind Wissen, how long a fetched copy counts as
  /// fresh, and how long a fetch may take.
  static const String knowledgeFeedUrl =
      'https://www.myfodmap.at/blog-feed.xml';
  static const Duration knowledgeFeedMaxAge = Duration(hours: 6);
  static const Duration knowledgeFeedTimeout = Duration(seconds: 10);

  // Apple "Hide My Email" relay address suffix (includes the leading `@`).
  // See the Sign in with Apple docs — this domain is stable since iOS 13.
  static const String appleRelayEmailSuffix = '@privaterelay.appleid.com';

  // SharedPreferences keys
  static const String keyNotificationModalShown = 'notification_modal_shown';
  static const String keyKnowledgeFeedCache = 'knowledge_feed_cache_v1';
  static const String keyBuddyStatePrefix = 'buddy_state_';

  /// Prefix of the Buddy announcement flags
  /// (`buddy_announced_<userId>_<kind>_<yyyy-MM-dd | goal>`), set once an
  /// announcement was shown, so each one shows only once.
  static const String keyBuddyAnnouncedPrefix = 'buddy_announced_';

  /// Maximum length of the Buddy's name, in characters as a person sees
  /// them (grapheme clusters: an emoji is one).
  static const int buddyNameMaxLength = 20;

  /// What the `buddy_state.name` check takes: the database counts code
  /// points up to 400 (core 0011), so 20 emojis fit, even long ZWJ ones.
  static const int buddyNameMaxCodePoints = 400;

  /// Whether [name] is a valid Buddy name: 1 to [buddyNameMaxLength]
  /// characters after trimming, and storable ([buddyNameMaxCodePoints]).
  static bool isValidBuddyName(String name) {
    final trimmed = name.trim();
    final length = trimmed.characters.length;
    return length > 0 &&
        length <= buddyNameMaxLength &&
        trimmed.runes.length <= buddyNameMaxCodePoints;
  }

  /// App Store numeric ID for Belly Buddy, used by the upgrade screen and
  /// dialog to open the store listing (App Store Connect → App Information →
  /// Apple ID). The `deploy-ios` job refuses the old placeholder `0000000000`.
  static const String iosAppStoreId = '6760981838';

  /// Builds the App Store URL for the current app.
  static String appStoreUrl() => 'https://apps.apple.com/app/id$iosAppStoreId';

  /// Builds the Play Store URL for the given Android package name.
  static String playStoreUrl(String packageName) =>
      'https://play.google.com/store/apps/details?id=$packageName';

  // Icon sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 18.0;
  static const double iconSizeClose = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;

  // Shadow
  static const double shadowBlurSm = 8.0;

  // Button
  static const double buttonHeight = 56.0;

  // Bottom nav
  static const double bottomNavCenterButtonSize = 80.0;

  /// The largest text scale the bottom bar's labels follow; above it they
  /// stay this size (like iOS's own tab bars), so five slots keep fitting.
  static const double bottomNavMaxTextScale = 1.3;

  /// The diameter of the news dot on a bottom-bar icon.
  static const double navBadgeSize = 10.0;

  // Durations
  static const Duration pressScaleDuration = Duration(milliseconds: 100);
  static const Duration successOverlayDuration = Duration(milliseconds: 1500);
  static const Duration autoAdvanceDuration = Duration(seconds: 4);
  static const Duration debounceDuration = Duration(milliseconds: 800);

  /// Back in the foreground, the tips and Alternativen load again only once
  /// their last load is at least this old (pushes and pull to refresh load
  /// regardless).
  static const Duration discoverNewsForegroundInterval = Duration(minutes: 5);

  /// The longest the app waits on its loading screen for the Buddy
  /// onboarding gate's answer after sign-in or app start; then it goes on
  /// as if no onboarding were due (a hanging backend never blocks the app).
  static const Duration buddyGateMaxWait = Duration(seconds: 3);

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animSlower = Duration(milliseconds: 600);

  // Asset paths
  static const String appIconPath = 'assets/images/app-icon.png';
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

  // Symptom options: kSymptomOptions in symptom_options.dart.

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
