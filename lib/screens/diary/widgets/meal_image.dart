import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../utils/signed_url_helper.dart';
import '../../../config/constants.dart';

class MealImage extends StatefulWidget {
  final String imageUrl;
  const MealImage({super.key, required this.imageUrl});

  @override
  State<MealImage> createState() => _MealImageState();
}

class _MealImageState extends State<MealImage> {
  String? _resolvedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await resolveSignedMealImageUrl(widget.imageUrl);
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
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_resolvedUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: CachedNetworkImage(
          imageUrl: _resolvedUrl!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            height: 180,
            color: AppTheme.muted,
          ),
          errorWidget: (_, _, _) => Container(
            height: 180,
            color: AppTheme.muted,
            child: const Center(
              child: Icon(Icons.image_not_supported,
                  color: AppTheme.mutedForeground),
            ),
          ),
        ),
      ),
    );
  }
}
