import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/meal_media_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockStorageService storageService;
  late MockEdgeFunctionService edgeFunctionService;
  late MealMediaRepository repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    storageService = MockStorageService();
    edgeFunctionService = MockEdgeFunctionService();
    repo = MealMediaRepository(storageService, edgeFunctionService);
  });

  group('uploadMealImage', () {
    test(
      'delegates to storageService.uploadImage with meal-images bucket',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        when(
          () => storageService.uploadImage(
            bucket: any(named: 'bucket'),
            userId: any(named: 'userId'),
            fileBytes: any(named: 'fileBytes'),
            extension: any(named: 'extension'),
          ),
        ).thenAnswer((_) async => '$testUserId/image.jpg');

        final result = await repo.uploadMealImage(
          userId: testUserId,
          fileBytes: bytes,
          extension: 'jpg',
        );

        expect(result, equals('$testUserId/image.jpg'));
        verify(
          () => storageService.uploadImage(
            bucket: 'meal-images',
            userId: testUserId,
            fileBytes: bytes,
            extension: 'jpg',
          ),
        ).called(1);
      },
    );
  });

  group('analyzeMealImage', () {
    test(
      'calls edge function analyze-meal with imageBase64 built from bytes',
      () async {
        final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
        const filename = 'photo.jpg';
        final expectedResult = {
          'title': 'Nudeln',
          'ingredients': ['Pasta', 'Tomaten'],
        };

        when(
          () => edgeFunctionService.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => expectedResult);

        final result = await repo.analyzeMealImage(bytes, filename);

        expect(result, equals(expectedResult));
        final captured =
            verify(
                  () => edgeFunctionService.invoke(
                    'analyze-meal',
                    body: captureAny(named: 'body'),
                  ),
                ).captured.single
                as Map<String, dynamic>;

        expect(captured.containsKey('imageBase64'), isTrue);
        final base64Value = captured['imageBase64'] as String;
        expect(base64Value, startsWith('data:image/jpeg;base64,'));
      },
    );

    test('rethrows exception from edge function', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => edgeFunctionService.invoke(any(), body: any(named: 'body')),
      ).thenThrow(Exception('edge function error'));

      expect(() => repo.analyzeMealImage(bytes, 'photo.jpg'), throwsException);
    });
  });

  group('triggerSuggestionRefresh', () {
    test(
      'invokes refresh-ingredient-suggestions edge function fire-and-forget',
      () async {
        when(
          () => edgeFunctionService.invoke(any()),
        ).thenAnswer((_) async => <String, dynamic>{});

        repo.triggerSuggestionRefresh();

        // Give the fire-and-forget call a moment to be initiated
        await Future<void>.delayed(Duration.zero);

        verify(
          () => edgeFunctionService.invoke('refresh-ingredient-suggestions'),
        ).called(1);
      },
    );
  });
}
