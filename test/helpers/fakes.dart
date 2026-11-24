import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
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

  /// Like the real one: leaves the weekly tips (setWeeklyTips' column) alone.
  @override
  Future<void> updateProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(
        userId: userId,
        weeklyTipsEnabled:
            _profile?.weeklyTipsEnabled ?? profile.weeklyTipsEnabled,
      );
  @override
  Future<void> updateTutorialSeenAt(String userId, DateTime? value) async {
    _tutorialUpdateCalled = true;
    _lastTutorialSeenAt = value;
    _profile = _profile?.copyWith(tutorialSeenAt: value);
  }

  /// When set, [setWeeklyTips] throws it instead of writing.
  Object? weeklyTipsError;

  /// The values [setWeeklyTips] was called with, in order.
  final List<bool> weeklyTipsWrites = [];

  @override
  Future<void> setWeeklyTips(String userId, bool enabled) async {
    weeklyTipsWrites.add(enabled);
    final error = weeklyTipsError;
    if (error != null) throw error;
    _profile = _profile?.copyWith(weeklyTipsEnabled: enabled);
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
  FakeEntryRepository({
    this.throwOnUpdate = false,
    this.throwOnDelete = false,
    this.countInsertsAsActivity = false,
  });

  /// When true, [updateEntry] throws on invocation. Used in tests that verify
  /// the screen stays open and surfaces the error rather than popping.
  final bool throwOnUpdate;

  /// When true, [deleteByType] throws on invocation (a delete that fails).
  final bool throwOnDelete;

  /// When true, [insertEntry] adds the row's local `tracked_at` day to the
  /// activity days, so the Buddy's refresh after a log sees it.
  final bool countInsertsAsActivity;

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

  /// What [fetchInsightSource] returns.
  InsightSource insightSource = const InsightSource(
    meals: [],
    gutFeelings: [],
    activityTimes: [],
  );

  /// When set, [fetchInsightSource] throws it.
  Object? insightSourceError;

  /// How often [fetchInsightSource] was called.
  int insightSourceCalls = 0;

  /// The `userId` and `now` of each [fetchInsightSource] call, in order.
  final insightSourceRequests = <({String userId, DateTime now})>[];

  /// While true, each [fetchInsightSource] call waits for its own completer,
  /// added to [heldInsightSources], so overlapping fetches can finish in any
  /// order.
  bool holdInsightSource = false;
  final heldInsightSources = <Completer<InsightSource>>[];

  @override
  Future<InsightSource> fetchInsightSource({
    required String userId,
    required DateTime now,
  }) async {
    insightSourceCalls++;
    insightSourceRequests.add((userId: userId, now: now));
    if (holdInsightSource) {
      final held = Completer<InsightSource>();
      heldInsightSources.add(held);
      return held.future;
    }
    final error = insightSourceError;
    if (error != null) throw error;
    return insightSource;
  }

  @override
  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async => _result.meals;

  /// What [fetchLatestBefore] returns.
  LatestEntries latestBefore = const LatestEntries();

  /// The `before` of each [fetchLatestBefore] call, in order.
  final List<DateTime> latestBeforeRequests = [];

  @override
  Future<LatestEntries> fetchLatestBefore({
    required String userId,
    required DateTime before,
  }) async {
    latestBeforeRequests.add(before);
    return latestBefore;
  }

  /// When set, [fetchForDate] throws it (a day that fails to load).
  Object? fetchForDateError;

  @override
  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async {
    final error = fetchForDateError;
    if (error != null) throw error;
    return _result;
  }

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
    if (countInsertsAsActivity) {
      final at = DateTime.parse(data['tracked_at'] as String).toLocal();
      _activityDays = {..._activityDays, DateTime(at.year, at.month, at.day)};
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
  Future<void> deleteByType(String type, String id) async {
    if (throwOnDelete) throw Exception('fake delete failure');
  }
}

// -- FakeDrinkRepository --
class FakeDrinkRepository implements DrinkRepository {
  List<Drink> _drinks = [testDrink()];

  void seedDrinks(List<Drink> drinks) => _drinks = drinks;

  /// The ids [fetchRecentDrinkIds] returns; null: every seeded drink.
  List<String>? recentDrinkIds;

  @override
  Future<List<Drink>> fetchAll() async => _drinks;
  @override
  Future<int> fetchDayTotal(String userId, DateTime day) async {
    dayTotalFetches.add(day);
    return 500;
  }

  /// The day of every [fetchDayTotal] call, in order.
  final List<DateTime> dayTotalFetches = [];
  @override
  Future<List<String>> fetchRecentDrinkIds(String userId) async =>
      recentDrinkIds ?? _drinks.map((d) => d.id).toList();
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
  /// [groups] are the suggestion groups it answers with; by default one new.
  FakeIngredientRepository({List<IngredientSuggestionGroup>? groups})
    : groups = groups ?? [testSuggestionGroup()];

  final List<IngredientSuggestionGroup> groups;

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
  ) async => groups;
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
  /// [sets], newest first; by default one set, seen on 1.11.2026, so
  /// nothing is new.
  FakeRecommendationRepository({List<Recommendation>? sets})
    : sets = sets ?? [testRecommendation(seenAt: DateTime.utc(2026, 11))];

  List<Recommendation> sets;
  int fetchCount = 0;

  @override
  Future<List<Recommendation>> fetchByUserId(String userId) async {
    fetchCount++;
    return sets;
  }

  /// Thrown by [markSeen] when set.
  Object? markError;

  /// The ids of every [markSeen], in order.
  final List<List<String>> marked = [];

  @override
  Future<void> markSeen(String userId, List<String> ids) async {
    marked.add(ids);
    if (markError case final error?) throw error;
    final now = DateTime.now().toUtc();
    sets = [
      for (final s in sets)
        s.seenAt == null && ids.contains(s.id) ? s.copyWith(seenAt: now) : s,
    ];
  }

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

  /// What [permissionStatus] reports.
  NotificationPermission permission = NotificationPermission.granted;

  @override
  Future<NotificationPermission> permissionStatus() async => permission;

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

  /// When set, [save] throws it (a refusal like the database's checks).
  Object? saveError;

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
    if (saveError case final error?) throw error;
    store[userId] = state.copyWith(userId: userId);
  }
}

// -- FakeBuddyNotifier --

/// A loaded Buddy status: a [BuddyState] row named [name] with the streak
/// figures.
BuddyStatus buddyStatus({
  String userId = testUserId,
  String name = 'Bubu',
  int? goal,
  int savers = 0,
  DateTime? onboardingCompletedAt,
  bool hasRow = true,
  int streak = 0,
  bool todayCounted = false,
  Set<DateTime> weekDays = const {},
  List<BuddyAnnouncement> announcements = const [],
}) => BuddyStatus(
  state: BuddyState(
    userId: userId,
    name: name,
    streakGoal: goal,
    savers: savers,
    onboardingCompletedAt: onboardingCompletedAt,
  ),
  hasRow: hasRow,
  streak: streak,
  todayCounted: todayCounted,
  weekDays: weekDays,
  announcements: announcements,
);

/// [BuddyNotifier] serving [initial] (none: no Buddy) without a backend.
/// Records names and goals: [setName] publishes the new name like the real
/// one, or throws while [failRename]; [setStreakGoal] throws while
/// [failGoal]. [push] publishes a status like a finished refresh.
class FakeBuddyNotifier extends BuddyNotifier {
  FakeBuddyNotifier([FutureOr<BuddyStatus?> Function()? initial])
    : _initial = initial;

  final FutureOr<BuddyStatus?> Function()? _initial;

  bool failRename = false;

  /// When set, [setName] throws it (instead of [failRename]'s error).
  Object? renameError;
  bool failGoal = false;
  final List<String> names = [];
  final List<int?> goals = [];

  /// When set, [setName] / [setStreakGoal] wait for it (a slow save).
  Future<void>? nameSave, goalSave;

  @override
  Future<BuddyStatus?> build() async => _initial?.call();

  @override
  Future<void> setName(String name) async {
    names.add(name);
    await nameSave;
    if (renameError case final error?) throw error;
    if (failRename) throw Exception('offline');
    final s = state.value!;
    push(
      BuddyStatus(
        state: s.state.copyWith(name: name),
        hasRow: true,
        streak: s.streak,
        todayCounted: s.todayCounted,
        weekDays: s.weekDays,
      ),
    );
  }

  @override
  Future<void> setStreakGoal(int? goal) async {
    goals.add(goal);
    await goalSave;
    if (failGoal) throw Exception('offline');
  }

  void push(BuddyStatus? status) => state = AsyncData(status);
}

/// An [InsightSource] with [activeDays] distinct active days and
/// [gutFeelings] gut-feeling entries, one per day at 09:00 on the days
/// before [now]'s, so all of them are in the insights' window as of [now].
/// Pass the clock the insights compute with ([buddyClockProvider]): pin it
/// to a fixed [now], never pair a fixed [now] with the real clock.
InsightSource insightSourceFor({
  required int activeDays,
  required int gutFeelings,
  required DateTime now,
}) {
  assert(
    activeDays < InsightRules.windowDays &&
        gutFeelings < InsightRules.windowDays,
  );
  DateTime dayBefore(int i) =>
      DateTime(now.year, now.month, now.day - 1 - i, 9);
  return InsightSource(
    meals: const [],
    gutFeelings: [
      for (var i = 0; i < gutFeelings; i++)
        testGutFeelingEntry(trackedAt: dayBefore(i)),
    ],
    activityTimes: [for (var i = 0; i < activeDays; i++) dayBefore(i)],
  );
}

class FakeKnowledgeRepository implements KnowledgeRepository {
  FakeKnowledgeRepository({List<KnowledgeArticle>? articles, this.cache})
    : articles = articles ?? testKnowledgeArticles();

  /// What [fetchArticles] answers (as they were when the call began).
  List<KnowledgeArticle> articles;

  /// Thrown by [fetchArticles] when set (as it was when the call began).
  Object? fetchError;
  int fetchCount = 0;

  /// While set and not completed, [fetchArticles] waits for it (a slow
  /// feed); a call keeps the hold it began with.
  Completer<void>? fetchHold;

  /// The in-memory cache.
  KnowledgeFeed? cache;

  /// Every feed passed to [writeCache].
  final List<KnowledgeFeed> written = [];

  @override
  Future<List<KnowledgeArticle>> fetchArticles() async {
    fetchCount++;
    final (error, result) = (fetchError, articles);
    if (fetchHold case final hold?) await hold.future;
    if (error != null) throw error;
    return result;
  }

  @override
  Future<KnowledgeFeed?> readCache() async => cache;

  @override
  Future<void> writeCache(KnowledgeFeed feed) async {
    written.add(feed);
    cache = feed;
  }
}

/// A [UrlOpener] that records each launch ([urls], [modes]) and answers
/// [result].
class RecordingUrlOpener {
  final urls = <Uri>[];
  final modes = <LaunchMode>[];
  bool result = true;

  Future<bool> call(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    urls.add(url);
    modes.add(mode);
    return Future.value(result);
  }
}
