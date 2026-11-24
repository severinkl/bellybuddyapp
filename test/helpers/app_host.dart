// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_localizations.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/discover_news_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/router/app_router.dart';

import 'fakes.dart';
import 'fixtures.dart';

/// The app's German localizations.
const germanLocalizations = appLocalizationsDelegates;

/// The app's one locale.
const germanLocale = Locale('de', 'DE');

/// A [GoRouter] app like the real one: the app theme, the German locale and
/// text scaled by [textScale].
Widget germanRouterApp(GoRouter router, {double textScale = 1}) =>
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      localizationsDelegates: germanLocalizations,
      supportedLocales: const [germanLocale],
      locale: germanLocale,
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
    );

/// Placeholder routes: each of [paths] shows `page:<path>`.
List<GoRoute> stubRoutes(Iterable<String> paths) => [
  for (final path in paths)
    GoRoute(
      path: path,
      builder: (_, _) => Scaffold(body: Text('page:$path')),
    ),
];

/// A Buddy that finished its onboarding long ago, so the onboarding gate
/// stays out of the way.
FakeBuddyRepository onboardedBuddyRepository() => FakeBuddyRepository()
  ..store[testUserId] = BuddyState(
    userId: testUserId,
    onboardingCompletedAt: DateTime(2026, 11, 1),
  );

/// Every repository the real router's screens reach, faked: signed in
/// ([auth]), [testUserProfile] ([profiles]), an onboarded Buddy
/// ([buddies]), no entries ([entries]), one seen tip set ([tips]), and the
/// upgrade [decision].
List<Override> baseOverrides({
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
  FakeBuddyRepository? buddies,
  FakeEntryRepository? entries,
  FakeIngredientRepository? ingredients,
  FakeRecommendationRepository? tips,
  UpgradeDecision decision = UpgradeDecision.ok,
}) => [
  authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(
    profiles ?? (FakeProfileRepository()..seedProfile(testUserProfile())),
  ),
  buddyRepositoryProvider.overrideWithValue(
    buddies ?? onboardedBuddyRepository(),
  ),
  entryRepositoryProvider.overrideWithValue(entries ?? FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
  ingredientRepositoryProvider.overrideWithValue(
    ingredients ?? FakeIngredientRepository(),
  ),
  recommendationRepositoryProvider.overrideWithValue(
    tips ?? FakeRecommendationRepository(),
  ),
  userRecipeRepositoryProvider.overrideWithValue(FakeUserRecipeRepository()),
  recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  notificationRepositoryProvider.overrideWithValue(
    FakeNotificationRepository(),
  ),
  knowledgeRepositoryProvider.overrideWithValue(FakeKnowledgeRepository()),
  upgradeDecisionProvider.overrideWith((_) => Future.value(decision)),
];

/// Pared-down app root: the real router, owning the upgrade decision and
/// keeping the tips and Alternativen loaded ([discoverNewsProvider]) like
/// [BellyBuddyApp], and loading the profile on start when signed in,
/// without the splash overlay. With [followAuth] it also loads the profile
/// on sign-in and resets it on sign-out, listening after the router like
/// the app.
class AppTestHost extends ConsumerStatefulWidget {
  const AppTestHost({super.key, this.followAuth = false});

  final bool followAuth;

  @override
  ConsumerState<AppTestHost> createState() => _AppTestHostState();
}

class _AppTestHostState extends ConsumerState<AppTestHost> {
  @override
  void initState() {
    super.initState();
    if (ref.read(isAuthenticatedProvider)) {
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    ref.watch(discoverNewsProvider);
    listenForUpgradeDecision(ref);
    if (widget.followAuth) {
      ref.listen<bool>(isAuthenticatedProvider, (_, signedIn) {
        final profile = ref.read(profileProvider.notifier);
        signedIn ? profile.fetchProfile() : profile.reset();
      });
    }
    return germanRouterApp(router);
  }
}
