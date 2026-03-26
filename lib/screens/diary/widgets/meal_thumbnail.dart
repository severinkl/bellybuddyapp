import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../repositories/meal_media_repository.dart';

class MealThumbnail extends ConsumerStatefulWidget {
  final String imageUrl;
  const MealThumbnail({super.key, required this.imageUrl});

  @override
  ConsumerState<MealThumbnail> createState() => _MealThumbnailState();
}

class _MealThumbnailState extends ConsumerState<MealThumbnail> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await ref
        .read(mealMediaRepositoryProvider)
        .resolveSignedUrl(widget.imageUrl);
    if (mounted) setState(() => _resolvedUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedUrl == null) {
      return Container(
        width: AppConstants.iconBadgeSm,
        height: AppConstants.iconBadgeSm,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusIcon),
        ),
        child: const Icon(Icons.restaurant, color: AppTheme.primary, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusIcon),
      child: CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        width: AppConstants.iconBadgeSm,
        height: AppConstants.iconBadgeSm,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: AppConstants.iconBadgeSm,
          height: AppConstants.iconBadgeSm,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusIcon),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: AppConstants.iconBadgeSm,
          height: AppConstants.iconBadgeSm,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusIcon),
          ),
          child: const Icon(
            Icons.restaurant,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
