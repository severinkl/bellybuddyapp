import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/auth_service.dart';
import 'package:belly_buddy/services/drink_service.dart';
import 'package:belly_buddy/services/edge_function_service.dart';
import 'package:belly_buddy/services/entry_crud_service.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/ingredient_service.dart';
import 'package:belly_buddy/services/profile_service.dart';
import 'package:belly_buddy/services/recipe_service.dart';
import 'package:belly_buddy/services/recommendation_service.dart';
import 'package:belly_buddy/services/storage_service.dart';

import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

// -- Supabase client mocks --
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestList> {}

class MockPostgrestMapNullableTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap?> {}

class MockPostgrestMapTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {}

// -- Service mocks --
class MockProfileService extends Mock implements ProfileService {}

class MockAuthService extends Mock implements AuthService {}

class MockEntryCrudService extends Mock implements EntryCrudService {}

class MockEntryQueryService extends Mock implements EntryQueryService {}

class MockDrinkService extends Mock implements DrinkService {}

class MockIngredientService extends Mock implements IngredientService {}

class MockRecipeService extends Mock implements RecipeService {}

class MockRecommendationService extends Mock implements RecommendationService {}

class MockStorageService extends Mock implements StorageService {}

class MockEdgeFunctionService extends Mock implements EdgeFunctionService {}

// -- Repository mocks --
class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockEntryRepository extends Mock implements EntryRepository {}

class MockDrinkRepository extends Mock implements DrinkRepository {}

class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockRecommendationRepository extends Mock
    implements RecommendationRepository {}

class MockMealMediaRepository extends Mock implements MealMediaRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}
