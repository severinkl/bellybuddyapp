import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import '../screens/screens.dart';
import '../config/app_theme.dart';
import '../widgets/common/bb_bottom_nav.dart';
import '../widgets/common/swipeable_pages.dart';
import 'route_names.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(isAuthenticatedProvider, (_, _) => notifyListeners());
  }
}

const _log = AppLogger('Router');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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

      if (!isAuthenticated) {
        // Allow unauthenticated users on welcome, auth, registration, reset-password
        if (isAuthRoute || path == RoutePaths.registration) return null;
        return RoutePaths.welcome;
      }

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

      // Shell route for bottom nav with swipe navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            backgroundColor: AppTheme.beige,
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
