import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/storage_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late MockStorageFileApi fileApi;
  late StorageService service;

  const bucket = 'meal-images';
  final fileBytes = Uint8List.fromList([0, 1, 2, 3]);

  setUp(() {
    client = MockSupabaseClient();
    fileApi = mockStorage(client, bucket: bucket);
    service = StorageService(client);
  });

  setUpAll(() {
    registerFallbackValue(const FileOptions());
    registerFallbackValue(Uint8List(0));
  });

  group('StorageService.uploadImage', () {
    test(
      'calls uploadBinary on the correct bucket with the right file bytes',
      () async {
        when(
          () => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).thenAnswer((_) async => '');

        await service.uploadImage(
          bucket: bucket,
          userId: testUserId,
          fileBytes: fileBytes,
          extension: 'jpg',
        );

        verify(
          () => fileApi.uploadBinary(
            any(),
            fileBytes,
            fileOptions: any(named: 'fileOptions'),
          ),
        ).called(1);
      },
    );

    test(
      'generates filename with userId prefix and correct extension',
      () async {
        String? capturedPath;
        when(
          () => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).thenAnswer((inv) async {
          capturedPath = inv.positionalArguments[0] as String;
          return '';
        });

        await service.uploadImage(
          bucket: bucket,
          userId: testUserId,
          fileBytes: fileBytes,
          extension: 'png',
        );

        expect(capturedPath, startsWith('$testUserId/'));
        expect(capturedPath, endsWith('.png'));
      },
    );

    test('returns the generated file path', () async {
      when(
        () => fileApi.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async => '');

      final result = await service.uploadImage(
        bucket: bucket,
        userId: testUserId,
        fileBytes: fileBytes,
        extension: 'jpg',
      );

      expect(result, startsWith('$testUserId/'));
      expect(result, endsWith('.jpg'));
    });
  });

  group('StorageService.getSignedUrl', () {
    test('calls createSignedUrl with path and expiresIn', () async {
      const path = 'test-user/image.jpg';
      const signedUrl = 'https://signed.url/image.jpg';
      when(
        () => fileApi.createSignedUrl(any(), any()),
      ).thenAnswer((_) async => signedUrl);

      final result = await service.getSignedUrl(bucket: bucket, path: path);

      expect(result, signedUrl);
      verify(() => fileApi.createSignedUrl(path, 3600)).called(1);
    });

    test('passes custom expiresIn to createSignedUrl', () async {
      const path = 'test-user/image.jpg';
      when(
        () => fileApi.createSignedUrl(any(), any()),
      ).thenAnswer((_) async => 'https://signed.url/image.jpg');

      await service.getSignedUrl(bucket: bucket, path: path, expiresIn: 7200);

      verify(() => fileApi.createSignedUrl(path, 7200)).called(1);
    });
  });

  group('StorageService.getPublicUrl', () {
    test('calls getPublicUrl with path and returns the result', () {
      const path = 'public/image.jpg';
      const publicUrl = 'https://cdn.example.com/public/image.jpg';
      when(() => fileApi.getPublicUrl(any())).thenReturn(publicUrl);

      final result = service.getPublicUrl(bucket: bucket, path: path);

      expect(result, publicUrl);
      verify(() => fileApi.getPublicUrl(path)).called(1);
    });
  });
}
