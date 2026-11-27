import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/meal_entry.dart';
import '../models/meal_prefill.dart';
import '../providers/auth_provider.dart';
import '../providers/buddy_onboarding_gate_provider.dart';
import '../providers/health_consent_provider.dart';
import '../providers/home_cover_provider.dart';
import '../providers/upgrade_gate_provider.dart';
import '../utils/logger.dart';
import '../screens/screens.dart';
import '../config/app_theme.dart';
import '../widgets/common/bb_bottom_nav.dart';
import 'route_names.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(isAuthenticatedProvider, (_, _) => notifyListeners());
    ref.listen(hardGateActiveProvider, (_, _) => notifyListeners());
    ref.listen(healthConsentRequiredProvider, (_, _) => notifyListeners());
    ref.listen(buddyOnboardingRequiredProvider, (_, _) => notifyListeners());
    ref.listen(buddyOnboardingGatePendingProvider, (_, _) => notifyListeners());
  }
}

const _log = AppLogger('Router');

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

/// The navigator of Home's tab, whose sheets cover Home too
/// ([HomeCoverObserver]).
final homeNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'home'),
);

final routerProvider = Provider<GoRouter>((ref) {
  final navigatorKey = ref.read(navigatorKeyProvider);
  final homeNavigatorKey = ref.read(homeNavigatorKeyProvider);
  return GoRouter(
    navigatorKey: navigatorKey,
    // Sheets, dialogs and menus over Home cover it, so the Buddy waits.
    observers: [
      HomeCoverObserver(
        () => ref.read(homeCoveredProvider.notifier),
        navigators: [navigatorKey, homeNavigatorKey],
      ),
    ],
    initialLocation: RoutePaths.welcome,
    refreshListenable: _RouterRefreshNotifier(ref),
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final path = state.matchedLocation;

      final isAuthRoute =
          path == RoutePaths.welcome ||
          path == RoutePaths.auth ||
          path == RoutePaths.resetPassword;

      _log.debug('redirect: path=$path auth=$isAuthenticated');

      // The hard upgrade gate wins over everything else: while it is active
      // every location (notification taps, pending routes, deep links)
      // resolves to the upgrade-required screen, so the user cannot leave it
      // until they update. Without the gate the screen is not reachable.
      if (ref.read(hardGateActiveProvider)) {
        return path == RoutePaths.upgradeRequired
            ? null
            : RoutePaths.upgradeRequired;
      }
      if (path == RoutePaths.upgradeRequired) {
        return isAuthenticated ? RoutePaths.dashboard : RoutePaths.welcome;
      }

      if (!isAuthenticated) {
        // Allow unauthenticated users on welcome, auth, registration, reset-password
        if (isAuthRoute || path == RoutePaths.registration) return null;
        return RoutePaths.welcome;
      }

      // Health-data consent gate (GDPR Art. 9): a signed-in user whose loaded
      // profile has no consent for the current privacy policy version can
      // only see the consent screen. It ranks below the upgrade gate and the
      // signed-out branch above, so sign-in / reset flows stay reachable for
      // signed-out users; signing out from the consent screen lifts it.
      if (ref.read(healthConsentRequiredProvider)) {
        return path == RoutePaths.healthConsent
            ? null
            : RoutePaths.healthConsent;
      }
      if (path == RoutePaths.healthConsent) return RoutePaths.dashboard;

      // Buddy onboarding gate: a signed-in user with a complete, consented
      // profile whose Buddy onboarding isn't done (users from before the
      // Buddy, or the app was killed mid-onboarding) is sent from the shell
      // roots to /buddy-onboarding; pushes from inside the flow stay. Until
      // the gate knows (profile and Buddy loading after sign-in or app
      // start), the shell roots wait on /loading, so no dashboard frame
      // shows before the onboarding. No redirect away once it is done: the
      // onboarding completes on its last step and leaves for the dashboard
      // itself.
      final buddyRedirect = buddyOnboardingRedirect(
        isRequired: ref.read(buddyOnboardingRequiredProvider),
        isPending: ref.read(buddyOnboardingGatePendingProvider),
        location: state.uri,
      );
      if (buddyRedirect != null) return buddyRedirect;

      // Authenticated on auth route → dashboard
      // NOTE: /registration is NOT in isAuthRoute — user stays there to finish
      // saving profile after signup before being redirected
      if (isAuthRoute) return RoutePaths.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.welcome,
        name: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        name: RouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.registration,
        name: RouteNames.registration,
        builder: (context, state) => const RegistrationWizardScreen(),
      ),

      // The four tabs (Home · Tagebuch · Entdecken · Ich) under the bottom
      // bar; the plus in its middle opens the „Eintragen" sheet. No swipe
      // between tabs: the Tagebuch swipes between days.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: navigationShell,
            bottomNavigationBar: BbBottomNav(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: homeNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.dashboard,
                name: RouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.diary,
                name: RouteNames.diary,
                builder: (context, state) => const DiaryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.discover,
                name: RouteNames.discover,
                builder: (context, state) => const DiscoverScreen(),
                routes: [
                  GoRoute(
                    path: 'knowledge',
                    name: RouteNames.knowledge,
                    builder: (context, state) => const KnowledgeScreen(),
                  ),
                  GoRoute(
                    path: 'recipes',
                    name: RouteNames.discoverRecipes,
                    builder: (context, state) => const CollectionScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.me,
                name: RouteNames.me,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),

      // Tracker routes (pushed on top of shell)
      GoRoute(
        path: RoutePaths.mealTracker,
        name: RouteNames.mealTracker,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is MealPrefill) {
            return MealTrackerScreen(initialRecipe: extra);
          }
          if (extra is DateTime) {
            return MealTrackerScreen(initialDate: extra);
          }
          return const MealTrackerScreen();
        },
      ),
      GoRoute(
        path: RoutePaths.mealTrackerEdit,
        name: RouteNames.mealTrackerEdit,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // The detail sheet passes the full MealEntry via `extra` so we can
          // seed the form without a provider lookup. Deep links (cold start)
          // arrive without `extra`; in that case the screen falls back to
          // looking the meal up by id, which may yield the "not found" state
          // since the diary's entries aren't cached in entriesProvider.
          final extra = state.extra;
          return MealTrackerScreen(
            mealId: id,
            initial: extra is MealEntry ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.toiletTracker,
        name: RouteNames.toiletTracker,
        builder: (context, state) {
          final extra = state.extra;
          return ToiletTrackerScreen(
            initialDate: extra is DateTime ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.gutFeelingTracker,
        name: RouteNames.gutFeelingTracker,
        builder: (context, state) {
          final extra = state.extra;
          return GutFeelingTrackerScreen(
            initialDate: extra is DateTime ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.drinkTracker,
        name: RouteNames.drinkTracker,
        builder: (context, state) {
          final extra = state.extra;
          return DrinkTrackerScreen(
            initialTrackedAt: extra is DateTime ? extra : null,
          );
        },
      ),

      // Settings routes
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            name: RouteNames.settingsProfile,
            builder: (context, state) => const SettingsProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            name: RouteNames.settingsNotifications,
            builder: (context, state) => const SettingsNotificationsScreen(),
          ),
          GoRoute(
            path: 'account',
            name: RouteNames.settingsAccount,
            builder: (context, state) => const SettingsAccountScreen(),
          ),
        ],
      ),

      // Share routes
      GoRoute(
        path: RoutePaths.shares,
        name: RouteNames.shares,
        builder: (context, state) => const SharesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.shareCreate,
            builder: (context, state) => const ShareCreateScreen(),
          ),
          GoRoute(
            path: 'connect',
            name: RouteNames.dietitianConnect,
            builder: (context, state) => const DietitianConnectScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            name: RouteNames.dietitianShareEdit,
            builder: (context, state) =>
                DietitianShareEditScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // Feature routes
      GoRoute(
        path: RoutePaths.recommendations,
        name: RouteNames.recommendations,
        builder: (context, state) => const RecommendationsScreen(),
      ),
      // The Muster page behind Home's insight card.
      GoRoute(
        path: RoutePaths.patterns,
        name: RouteNames.patterns,
        builder: (context, state) => const PatternsScreen(),
      ),
      // Day 7's celebration; the Buddy pushes it when the patterns unlock.
      GoRoute(
        path: RoutePaths.patternsUnlocked,
        name: RouteNames.patternsUnlocked,
        builder: (context, state) => const PatternsUnlockedScreen(),
      ),
      GoRoute(
        path: RoutePaths.ingredientSuggestions,
        name: RouteNames.ingredientSuggestions,
        builder: (context, state) => const IngredientSuggestionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.recipes,
        name: RouteNames.recipes,
        builder: (context, state) => const RecipesScreen(),
      ),
      GoRoute(
        path: RoutePaths.recipeNew,
        name: RouteNames.recipeNew,
        builder: (context, state) {
          final extra = state.extra;
          return RecipeEditorScreen(
            initialMeal: extra is MealEntry ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.recipeDetail,
        name: RouteNames.recipeDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeDetailScreen(recipeId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.recipeEdit,
        name: RouteNames.recipeEdit,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeEditorScreen(recipeId: id);
        },
      ),
      // A recipe of the collection, pushed over the shell (no bar).
      GoRoute(
        path: RoutePaths.collectionRecipe,
        name: RouteNames.collectionRecipe,
        builder: (context, state) =>
            CollectionRecipeScreen(recipeId: state.pathParameters['id']!),
      ),
      // „Für mich anpassen": sends only when pushed with `extra: true` (the
      // detail's button); opened any other way, it asks first.
      GoRoute(
        path: RoutePaths.collectionRecipeAdapt,
        name: RouteNames.collectionRecipeAdapt,
        builder: (context, state) => AdaptRecipeScreen(
          recipeId: state.pathParameters['id']!,
          requested: state.extra == true,
        ),
      ),
      GoRoute(
        path: RoutePaths.upgradeRequired,
        name: RouteNames.upgradeRequired,
        builder: (_, _) => const UpgradeRequiredScreen(),
      ),
      GoRoute(
        path: RoutePaths.healthConsent,
        name: RouteNames.healthConsent,
        builder: (_, _) => const HealthConsentScreen(),
      ),
      GoRoute(
        path: RoutePaths.loading,
        name: RouteNames.loading,
        builder: (_, _) => const LoadingScreen(),
      ),
      GoRoute(
        path: RoutePaths.buddyOnboarding,
        name: RouteNames.buddyOnboarding,
        builder: (context, state) {
          final extra = state.extra;
          return BuddyOnboardingScreen(
            entry: extra is BuddyOnboardingEntry
                ? extra
                : BuddyOnboardingEntry.gate,
          );
        },
      ),
    ],
  );
});
