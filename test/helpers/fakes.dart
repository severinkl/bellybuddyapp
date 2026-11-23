import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/repositories/user_recipe_repository.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/ingredient_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures.dart';

// -- FakeAuthRepository --
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signedIn = true,
    this.onSignedIn,
    this.onSignedOut,
    this.shouldFailEmailSignIn = false,
    this.signInErrorMessage = 'Login failed',
    this.signInEmail,
  }) {
    if (signedIn) {
      _currentUser = _buildUser();
      _currentSession = _buildSession();
    }
  }

  bool signedIn;
  void Function(User user)? onSignedIn;
  VoidCallback? onSignedOut;
  bool shouldFailEmailSignIn;
  String signInErrorMessage;

  /// Email the built Supabase [User] reports. Omit / pass null to simulate
  /// Apple second-sign-in (no email). Pass a real address to simulate
  /// Google. Pass an `@privaterelay.appleid.com` address to simulate
  /// Apple's Hide My Email.
  final String? signInEmail;

  final _authStateController = StreamController<AuthState>.broadcast();

  User? _currentUser;
  Session? _currentSession;

  Map<String, dynamic> _buildUserJson() => {
    'id': testUserId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': DateTime.now().toIso8601String(),
    if (signInEmail != null) 'email': signInEmail,
  };

  User? _buildUser() {
    return User.fromJson(_buildUserJson());
  }

  Session? _buildSession() {
    return Session.fromJson({
      'access_token': 'fake-access-token',
      'refresh_token': 'fake-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
      'user': _buildUserJson(),
    });
  }

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    if (shouldFailEmailSignIn) {
      throw AuthException(signInErrorMessage);
    }
    signedIn = true;
    _currentUser = _buildUser();
    _currentSession = _buildSession();

    onSignedIn?.call(_currentUser!);
    _authStateController.add(
      AuthState(AuthChangeEvent.signedIn, _currentSession),
    );

    return AuthResponse(session: _currentSession, user: _currentUser);
  }

  @override
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    signedIn = true;
    _currentUser = _buildUser();
    _currentSession = _buildSession();

    onSignedIn?.call(_currentUser!);
    _authStateController.add(
      AuthState(AuthChangeEvent.signedIn, _currentSession),
    );

    return AuthResponse(session: _currentSession, user: _currentUser);
  }

  @override
  Future<AuthResponse> signInWithGoogle() async {
    signedIn = true;
    _currentUser = _buildUser();
    _currentSession = _buildSession();

    onSignedIn?.call(_currentUser!);
    _authStateController.add(
      AuthState(AuthChangeEvent.signedIn, _currentSession),
    );

    return AuthResponse(session: _currentSession, user: _currentUser);
  }

  @override
  Future<AuthResponse> signInWithApple() async {
    signedIn = true;
    _currentUser = _buildUser();
    _currentSession = _buildSession();

    onSignedIn?.call(_currentUser!);
    _authStateController.add(
      AuthState(AuthChangeEvent.signedIn, _currentSession),
    );

    return AuthResponse(session: _currentSession, user: _currentUser);
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    _currentUser = null;
    _currentSession = null;

    onSignedOut?.call();
    _authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<UserResponse> updatePassword(String newPassword) async =>
      UserResponse.fromJson(_buildUserJson());

  @override
  Future<void> deleteAccount() async {}

  @override
  String? detectAuthMethod() => 'email';

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => signedIn;

  void dispose() {
    _authStateController.close();
  }
}

// -- FakeProfileRepository --
class FakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;
  DateTime? _lastTutorialSeenAt;
  bool _tutorialUpdateCalled = false;

  void seedProfile(UserProfile profile) => _profile = profile;

  /// Email on the most recently created/updated profile, for tests.
  String? get lastWrittenEmail => _profile?.email;
  DateTime? get lastTutorialSeenAt => _lastTutorialSeenAt;
  bool get tutorialUpdateCalled => _tutorialUpdateCalled;

  @override
  Future<UserProfile?> getProfile(String userId) async => _profile;
  @override
  Future<void> createProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
  @override
  Future<void> updateProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
  @override
  Future<void> updateTutorialSeenAt(String userId, DateTime? value) async {
    _tutorialUpdateCalled = true;
    _lastTutorialSeenAt = value;
    _profile = _profile?.copyWith(tutorialSeenAt: value);
  }

  /// Number of [acceptHealthConsent] calls, for tests.
  int acceptHealthConsentCount = 0;

  /// When set, [acceptHealthConsent] throws it instead of writing.
  Object? acceptHealthConsentError;

  /// The profile as last written, for asserting persisted consent fields.
  UserProfile? get storedProfile => _profile;

  @override
  Future<DateTime> acceptHealthConsent(String userId, {DateTime? now}) async {
    acceptHealthConsentCount++;
    final error = acceptHealthConsentError;
    if (error != null) throw error;
    final acceptedAt = (now ?? DateTime.now()).toUtc();
    _profile = _profile?.copyWith(
      healthConsentAt: acceptedAt,
      privacyPolicyVersion: AppConstants.privacyPolicyVersion,
    );
    return acceptedAt;
  }
}

// -- FakeEntryRepository --
class FakeEntryRepository implements EntryRepository {
  FakeEntryRepository({this.throwOnUpdate = false});

  /// When true, [updateEntry] throws on invocation. Used in tests that verify
  /// the screen stays open and surfaces the error rather than popping.
  final bool throwOnUpdate;

  final List<Map<String, dynamic>> _inserted = [];

  /// Meal payloads that were inserted via [insertEntry], reconstructed as
  /// [MealEntry]s for easy assertions in tests.
  final List<MealEntry> addedMeals = [];

  /// Meal payloads that were passed to [updateEntry], reconstructed as
  /// [MealEntry]s (the id is taken from the `updateEntry` argument and merged
  /// into the data map before parsing).
  final List<MealEntry> updatedMeals = [];

  List<Map<String, dynamic>> get inserted => _inserted;
  EntryQueryResult _result = testEntryQueryResult();

  void seedResult(EntryQueryResult result) => _result = result;

  Set<DateTime> _activityDays = {};

  /// Number of [fetchActivityDays] calls.
  int activityDaysFetchCount = 0;

  /// The range of every [fetchActivityDays] call, in order.
  final List<({DateTime since, DateTime? until})> activityDaysFetches = [];

  void seedActivityDays(Set<DateTime> days) => _activityDays = days;

  @override
  Future<Set<DateTime>> fetchActivityDays({
    required String userId,
    required DateTime since,
    DateTime? until,
  }) async {
    activityDaysFetchCount++;
    activityDaysFetches.add((since: since, until: until));
    final from = DateTime(since.year, since.month, since.day);
    final to = until == null
        ? null
        : DateTime(until.year, until.month, until.day);
    return _activityDays.where((d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(from) && (to == null || day.isBefore(to));
    }).toSet();
  }

  /// What [fetchInsightProgress] returns.
  InsightProgress insightProgress = const InsightProgress(
    activeDays: 0,
    gutFeelingEntries: 0,
  );

  /// When set, [fetchInsightProgress] throws it.
  Object? insightProgressError;

  /// The `now` of every [fetchInsightProgress] call, in order.
  final List<DateTime> insightProgressFetches = [];

  @override
  Future<InsightProgress> fetchInsightProgress({
    required String userId,
    required DateTime now,
  }) async {
    insightProgressFetches.add(now);
    final error = insightProgressError;
    if (error != null) throw error;
    return insightProgress;
  }

  @override
  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async => _result.meals;

  @override
  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async => _result;
  @override
  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    _inserted.add(data);
    if (table == 'meal_entries') {
      addedMeals.add(MealEntry.fromJson(data));
    }
  }

  @override
  Future<void> updateEntry(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (throwOnUpdate) throw Exception('fake update failure');
    if (table == 'meal_entries') {
      updatedMeals.add(MealEntry.fromJson({...data, 'id': id}));
    }
  }

  @override
  Future<void> deleteEntry(String table, String id) async {}
  @override
  Future<void> deleteByType(String type, String id) async {}
}

// -- FakeDrinkRepository --
class FakeDrinkRepository implements DrinkRepository {
  List<Drink> _drinks = [testDrink()];

  void seedDrinks(List<Drink> drinks) => _drinks = drinks;

  @override
  Future<List<Drink>> fetchAll() async => _drinks;
  @override
  Future<int> fetchTodayTotal(String userId) async => 500;
  @override
  Future<List<String>> fetchRecentDrinkIds(String userId) async =>
      _drinks.map((d) => d.id).toList();
  @override
  Future<Drink> insertDrink(String name, {required String userId}) async {
    final drink = testDrink(id: 'new-drink', name: name, addedByUserId: userId);
    _drinks = [..._drinks, drink];
    return drink;
  }

  @override
  Future<void> deleteDrink(String drinkId) async =>
      _drinks = _drinks.where((d) => d.id != drinkId).toList();
}

// -- FakeIngredientRepository --
class FakeIngredientRepository implements IngredientRepository {
  @override
  Future<List<IngredientSearchResult>> search(
    String query, {
    required String? userId,
    int limit = 10,
  }) async => [testIngredientSearchResult(name: query)];
  @override
  Future<void> insertIfNew(String name, {required String? userId}) async {}
  @override
  Future<void> deleteUserIngredient(String id) async {}
  @override
  Future<List<IngredientSuggestionGroup>> fetchSuggestionGroups(
    String userId,
  ) async => [testSuggestionGroup()];
  @override
  Future<void> markAllSeen(List<String> ids) async {}
  @override
  Future<void> dismissSuggestions(List<String> ids) async {}
  @override
  Future<int> fetchNewCount(String userId) async => 0;
}

// -- FakeRecipeRepository --
class FakeRecipeRepository implements RecipeRepository {
  List<Recipe> _recipes = [testRecipe()];
  Set<String> _favorites = {};

  void seedRecipes(List<Recipe> recipes) => _recipes = recipes;

  @override
  Future<List<Recipe>> fetchAll() async => _recipes;
  @override
  Future<Set<String>> fetchFavoriteIds(String userId) async => _favorites;
  @override
  Future<void> addFavorite(String userId, String recipeId) async =>
      _favorites = {..._favorites, recipeId};
  @override
  Future<void> removeFavorite(String userId, String recipeId) async =>
      _favorites = _favorites.where((id) => id != recipeId).toSet();
}

// -- FakeUserRecipeRepository --
class FakeUserRecipeRepository implements UserRecipeRepository {
  FakeUserRecipeRepository({List<UserRecipe>? seed}) : _recipes = [...?seed];

  final List<UserRecipe> _recipes;

  void seedRecipes(List<UserRecipe> recipes) {
    _recipes
      ..clear()
      ..addAll(recipes);
  }

  @override
  Future<List<UserRecipe>> fetchForUser(String userId) async =>
      List.unmodifiable(_recipes);

  @override
  Future<List<UserRecipe>> searchForUser(String userId, String query) async {
    final q = query.toLowerCase();
    return _recipes
        .where((r) => r.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    final created = testUserRecipe(
      id: 'rec-${_recipes.length + 1}',
      userId: userId,
      title: title,
      ingredients: ingredients,
      imageUrl: imageUrl,
    );
    _recipes.add(created);
    return created;
  }

  @override
  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    final i = _recipes.indexWhere((r) => r.id == id);
    if (i < 0) throw StateError('UserRecipe $id not found');
    final next = testUserRecipe(
      id: id,
      userId: _recipes[i].userId,
      title: title,
      ingredients: ingredients,
      imageUrl: imageUrl,
    );
    _recipes[i] = next;
    return next;
  }

  @override
  Future<void> delete(String id) async {
    _recipes.removeWhere((r) => r.id == id);
  }
}

// -- FakeRecommendationRepository --
class FakeRecommendationRepository implements RecommendationRepository {
  @override
  Future<List<Recommendation>> fetchByUserId(String userId) async => [
    testRecommendation(),
  ];
  @override
  Future<int> countUnseen(String userId) async => 0;
  @override
  Future<void> markAllAsSeen(String userId) async {}
  @override
  Future<void> updateFeedback({
    required String id,
    required RecommendationState state,
    String? dislikeComment,
  }) async {}
}

// -- FakeMealMediaRepository --
class FakeMealMediaRepository implements MealMediaRepository {
  FakeMealMediaRepository({this.uploadResult = 'test-user/image.jpg'});

  /// URL returned from [uploadMealImage] — override in tests that need to
  /// assert specific image URLs end-to-end.
  final String uploadResult;

  @override
  Future<String> uploadMealImage({
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) async => uploadResult;
  @override
  Future<Map<String, dynamic>> analyzeMealImage(
    Uint8List bytes,
    String filename,
  ) async => {
    'title': 'Erkanntes Gericht',
    'ingredients': ['Reis', 'Gemüse'],
  };
  @override
  void triggerSuggestionRefresh() {}
  @override
  Future<String?> resolveSignedUrl(String? urlOrPath) async => urlOrPath;
}

// -- testUserRecipe factory --

UserRecipe testUserRecipe({
  String id = 'rec-1',
  String userId = 'user-1',
  String title = 'Curry mit Reis',
  List<String> ingredients = const ['Reis', 'Curry'],
  String? imageUrl,
  DateTime? createdAt,
}) => UserRecipe(
  id: id,
  userId: userId,
  title: title,
  ingredients: ingredients,
  imageUrl: imageUrl,
  createdAt: createdAt ?? DateTime.utc(2026, 4, 24),
  updatedAt: createdAt ?? DateTime.utc(2026, 4, 24),
);

// -- FakeNotificationRepository --
class FakeNotificationRepository implements NotificationRepository {
  int syncCount = 0;

  @override
  Future<void> syncNotifications(
    UserProfile profile, {
    String? buddyName,
  }) async => syncCount++;
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<RemoteMessage> get onForegroundMessage => const Stream.empty();
  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  String? extractRoute(RemoteMessage message) => null;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> requestAllPermissions() async => true;
  @override
  Future<void> clearToken() async {}
}

class FakeBuddyRepository implements BuddyRepository {
  final Map<String, BuddyState> store = {};
  int fetchCount = 0;
  int saveCount = 0;
  bool throwOnFetch = false;
  bool throwOnSave = false;

  /// While set and not completed, every [fetch] (or [save]) waits for it
  /// (a slow or hanging backend).
  Completer<void>? fetchHold;
  Completer<void>? saveHold;

  /// The `retry` argument of every [fetch], in order.
  final List<bool> fetchRetries = [];

  @override
  Future<BuddyState?> fetch(String userId, {bool retry = true}) async {
    fetchCount++;
    fetchRetries.add(retry);
    if (fetchHold case final hold?) await hold.future;
    if (throwOnFetch) throw Exception('fetch failed');
    return store[userId];
  }

  @override
  Future<void> save(String userId, BuddyState state) async {
    saveCount++;
    if (saveHold case final hold?) await hold.future;
    if (throwOnSave) throw Exception('save failed');
    store[userId] = state.copyWith(userId: userId);
  }
}
