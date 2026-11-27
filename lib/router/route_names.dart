class RouteNames {
  RouteNames._();

  static const String welcome = 'welcome';
  static const String auth = 'auth';
  static const String resetPassword = 'reset-password';
  static const String registration = 'registration';
  static const String dashboard = 'dashboard';
  static const String mealTracker = 'meal-tracker';
  static const String mealTrackerEdit = 'meal-tracker-edit';
  static const String toiletTracker = 'toilet-tracker';
  static const String gutFeelingTracker = 'gut-feeling-tracker';
  static const String drinkTracker = 'drink-tracker';
  static const String diary = 'diary';
  static const String discover = 'discover';
  static const String knowledge = 'knowledge';
  static const String discoverRecipes = 'discover-recipes';
  static const String me = 'me';
  static const String settings = 'settings';
  static const String settingsProfile = 'settings-profile';
  static const String settingsNotifications = 'settings-notifications';
  static const String settingsAccount = 'settings-account';
  static const String shares = 'shares';
  static const String shareCreate = 'share-create';
  static const String dietitianConnect = 'dietitian-connect';
  static const String dietitianShareEdit = 'dietitian-share-edit';
  static const String recommendations = 'recommendations';
  static const String patterns = 'patterns';
  static const String patternsUnlocked = 'patterns-unlocked';
  static const String progress = 'progress';
  static const String relief = 'relief';
  static const String reliefExercise = 'relief-exercise';
  static const String ingredientSuggestions = 'ingredient-suggestions';
  static const String recipes = 'recipes';
  static const String recipeNew = 'recipe_new';
  static const String recipeDetail = 'recipe_detail';
  static const String recipeEdit = 'recipe_edit';
  static const String collectionRecipe = 'collection-recipe';
  static const String collectionRecipeAdapt = 'collection-recipe-adapt';
  static const String upgradeRequired = 'upgrade-required';
  static const String healthConsent = 'health-consent';
  static const String buddyOnboarding = 'buddy-onboarding';
  static const String loading = 'loading';
}

class RoutePaths {
  RoutePaths._();

  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String resetPassword = '/reset-password';
  static const String registration = '/registration';
  static const String dashboard = '/dashboard';
  static const String mealTracker = '/meal-tracker';
  static const String mealTrackerEdit = '/meal-tracker/:id';
  static String mealTrackerEditFor(String id) => '/meal-tracker/$id';
  static const String toiletTracker = '/toilet-tracker';
  static const String gutFeelingTracker = '/gut-feeling-tracker';
  static const String drinkTracker = '/drink-tracker';
  static const String diary = '/diary';
  static const String discover = '/discover';
  static const String knowledge = '/discover/knowledge';
  static const String discoverRecipes = '/discover/recipes';
  static const String me = '/me';
  static const String settings = '/settings';
  static const String settingsProfile = '/settings/profile';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsAccount = '/settings/account';
  static const String shares = '/shares';
  static const String shareCreate = '/shares/new';
  static const String dietitianConnect = '/shares/connect';
  static const String dietitianShareEdit = '/shares/:id/edit';
  static String dietitianShareEditFor(String id) => '/shares/$id/edit';
  static const String recommendations = '/recommendations';
  static const String patterns = '/patterns';
  static const String patternsUnlocked = '/patterns-unlocked';
  static const String progress = '/progress';
  static const String relief = '/relief';
  static const String reliefExercise = '/relief/:id';
  static String reliefExerciseFor(String id) => '/relief/$id';
  static const String ingredientSuggestions = '/ingredient-suggestions';
  static const String recipes = '/recipes';
  static const String recipeNew = '/recipe/new';
  static const String recipeDetail = '/recipe/:id';
  static const String recipeEdit = '/recipe/:id/edit';
  static String recipeDetailFor(String id) => '/recipe/$id';
  static String recipeEditFor(String id) => '/recipe/$id/edit';

  /// A recipe of the collection; `/recipe/:id` is an own recipe.
  static const String collectionRecipe = '/collection/:id';
  static const String collectionRecipeAdapt = '/collection/:id/adapt';
  static String collectionRecipeFor(String id) => '/collection/$id';
  static String collectionRecipeAdaptFor(String id) => '/collection/$id/adapt';
  static const String upgradeRequired = '/upgrade-required';
  static const String healthConsent = '/health-consent';
  static const String buddyOnboarding = '/buddy-onboarding';
  static const String loading = '/loading';
}
