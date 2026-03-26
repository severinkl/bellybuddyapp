import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/edge_function_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import '../utils/meal_helpers.dart';
import '../utils/signed_url_helper.dart';

class MealMediaRepository {
  final StorageService _storageService;
  final EdgeFunctionService _edgeFunctionService;
  static const _log = AppLogger('MealMediaRepository');

  MealMediaRepository(this._storageService, this._edgeFunctionService);

  Future<String> uploadMealImage({
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) => _storageService.uploadImage(
    bucket: 'meal-images',
    userId: userId,
    fileBytes: fileBytes,
    extension: extension,
  );

  /// Calls the `analyze-meal` edge function and returns the result map
  /// containing `title` and `ingredients`.
  Future<Map<String, dynamic>> analyzeMealImage(
    Uint8List bytes,
    String filename,
  ) async {
    final base64Data = MealHelpers.buildImageBase64(bytes, filename);
    try {
      return await _edgeFunctionService.invoke(
        'analyze-meal',
        body: {'imageBase64': base64Data},
      );
    } catch (e, st) {
      _log.error('analyzeMealImage failed', e, st);
      rethrow;
    }
  }

  /// Fire-and-forget call to trigger ingredient suggestion refresh.
  void triggerSuggestionRefresh() {
    _edgeFunctionService.invoke('refresh-ingredient-suggestions').ignore();
  }

  /// Resolves a meal image URL or storage path to a fresh signed URL.
  /// Returns null for null/empty input, returns as-is if already signed,
  /// and falls back to the original value on error.
  Future<String?> resolveSignedUrl(String? urlOrPath) async {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;
    if (urlOrPath.contains('token=')) return urlOrPath;

    try {
      final path = extractStoragePath(urlOrPath, 'meal-images');
      return await _storageService.getSignedUrl(
        bucket: 'meal-images',
        path: path,
      );
    } catch (e) {
      return urlOrPath;
    }
  }
}

final mealMediaRepositoryProvider = Provider<MealMediaRepository>(
  (ref) => MealMediaRepository(
    ref.watch(storageServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  ),
);
