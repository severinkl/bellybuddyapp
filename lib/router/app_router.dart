import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import '../providers/profile_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/diary/diary_screen.dart';
import '../screens/ingredient_suggestions/ingredient_suggestions_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/recommendations/recommendations_screen.dart';
import '../screens/recipes/recipes_screen.dart';
import '../screens/registration/registration_wizard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/widgets/settings_account_screen.dart';
import '../screens/settings/widgets/settings_notifications_screen.dart';
import '../screens/settings/widgets/settings_profile_screen.dart';
import '../screens/trackers/drink/drink_tracker_screen.dart';
import '../screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import '../screens/trackers/meal/meal_tracker_screen.dart';
import '../screens/trackers/toilet/toilet_tracker_screen.dart';
import '../widgets/common/bb_bottom_nav.dart';
import '../widgets/common/swipeable_pages.dart';
import 'route_names.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(isAuthenticatedProvider, (_, _) => notifyListeners());
    ref.listen(profileProvider, (_, _) => notifyListeners());
    ref.listen(isOnboardedProvider, (_, _) => notifyListeners());
  }
}

const _log = AppLogger('Router');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.onboarding,
    refreshListenable: _RouterRefreshNotifier(ref),
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isOnboarded =
          ref.read(isOnboardedProvider).asData?.value ?? false;
      final profileState = ref.read(profileProvider);
      final profileLoading = profileState.isLoading;
      final hasProfile = ref.read(hasProfileProvider);

      final path = state.matchedLocation;
      _log.debug('redirect: path=$path auth=$isAuthenticated onboarded=$isOnboarded profileLoading=$profileLoading hasProfile=$hasProfile');

      final isAuthRoute = path == RoutePaths.auth ||
          path == RoutePaths.onboarding ||
          path == RoutePaths.registration ||
          path == RoutePaths.resetPassword;

      // Not authenticated
      if (!isAuthenticated) {
        if (path == RoutePaths.onboarding || path == RoutePaths.auth || path == RoutePaths.resetPassword) {
          return null;
        }
        return isOnboarded ? RoutePaths.auth : RoutePaths.onboarding;
      }

      // Authenticated but profile not yet loaded — don't redirect yet
      if (profileLoading) {
        return null;
      }

      // Authenticated but profile fetch failed — stay put, don't redirect to registration
      if (profileState.hasError && !profileState.hasValue) {
        _log.debug('profile in error state, staying put');
        return null;
      }

      // Authenticated but no profile
      if (!hasProfile) {
        if (path == RoutePaths.registration) return null;
        return RoutePaths.registration;
      }

      // Authenticated with profile, on auth route
      if (hasProfile && isAuthRoute) {
        return RoutePaths.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
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

      // Shell route for bottom nav with swipe navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: SwipeablePages(
              currentIndex: navigationShell.currentIndex,
              pageCount: 2,
              onPageChanged: (index) => navigationShell.goBranch(index),
              child: navigationShell,
            ),
            bottomNavigationBar: BbBottomNav(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
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
        ],
      ),

      // Tracker routes (pushed on top of shell)
      GoRoute(
        path: RoutePaths.mealTracker,
        name: RouteNames.mealTracker,
        builder: (context, state) => const MealTrackerScreen(),
      ),
      GoRoute(
        path: RoutePaths.toiletTracker,
        name: RouteNames.toiletTracker,
        builder: (context, state) => const ToiletTrackerScreen(),
      ),
      GoRoute(
        path: RoutePaths.gutFeelingTracker,
        name: RouteNames.gutFeelingTracker,
        builder: (context, state) => const GutFeelingTrackerScreen(),
      ),
      GoRoute(
        path: RoutePaths.drinkTracker,
        name: RouteNames.drinkTracker,
        builder: (context, state) => const DrinkTrackerScreen(),
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

      // Feature routes
      GoRoute(
        path: RoutePaths.recommendations,
        name: RouteNames.recommendations,
        builder: (context, state) => const RecommendationsScreen(),
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
    ],
  );
});
