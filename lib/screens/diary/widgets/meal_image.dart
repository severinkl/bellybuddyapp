import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../repositories/meal_media_repository.dart';

class MealImage extends ConsumerStatefulWidget {
  final String imageUrl;
  const MealImage({super.key, required this.imageUrl});

  @override
  ConsumerState<MealImage> createState() => _MealImageState();
}

class _MealImageState extends ConsumerState<MealImage> {
  String? _resolvedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await ref
        .read(mealMediaRepositoryProvider)
        .resolveSignedUrl(widget.imageUrl);
    if (url == null) {
      debugPrint(
        '[MealImage] URL resolution returned null for: ${widget.imageUrl}',
      );
    }
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: AppConstants.mealImageHeight,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_resolvedUrl == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: AppConstants.mealImageHeight,
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: CachedNetworkImage(
          imageUrl: _resolvedUrl!,
          height: AppConstants.mealImageHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            height: AppConstants.mealImageHeight,
            color: AppTheme.muted,
          ),
          errorWidget: (_, _, _) => Container(
            height: AppConstants.mealImageHeight,
            color: AppTheme.muted,
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
