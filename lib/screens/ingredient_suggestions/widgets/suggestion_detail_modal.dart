import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_theme.dart';
import '../../../models/ingredient_suggestion_group.dart';
import '../../../config/constants.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/signed_url_helper.dart';
import '../../../utils/url_utils.dart';

class SuggestionDetailModal extends StatelessWidget {
  final IngredientSuggestionGroup group;

  const SuggestionDetailModal({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image and name
              Row(
                children: [
                  _IngredientImage(imageUrl: group.ingredientImageUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      group.ingredientName,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeTitleLG,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Helptext info box
              if (group.helptext != null && group.helptext!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: AppConstants.paddingMd,
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(
                      color: AppTheme.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppTheme.info,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          group.helptext!,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppTheme.foreground,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Meals section
              if (group.meals.isNotEmpty) ...[
                Text(
                  'Gefunden in ${group.mealCount} ${group.mealCount == 1 ? 'Speise' : 'Speisen'}',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap12,
                ...group.meals.map(
                  (meal) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          if (meal.imageUrl != null) ...[
                            _MealImage(imageUrl: meal.imageUrl!),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.title,
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontSizeBody,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDateShort(meal.trackedAt),
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontSizeCaption,
                                    color: AppTheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppConstants.gap12,
              ],

              // Alternatives section
              if (group.replacements.isNotEmpty) ...[
                const Text(
                  'Alternativen',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap12,
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: group.replacements.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final repl = group.replacements[index];
                      return SizedBox(
                        width: 80,
                        child: Column(
                          children: [
                            _IngredientImage(imageUrl: repl.imageUrl, size: 56),
                            const SizedBox(height: 6),
                            Text(
                              repl.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTheme.fontSizeCaption,
                                color: AppTheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                AppConstants.gap12,
              ],

              // Close button
              AppConstants.gap8,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MealImage extends StatefulWidget {
  final String imageUrl;

  const _MealImage({required this.imageUrl});

  @override
  State<_MealImage> createState() => _MealImageState();
}

class _MealImageState extends State<_MealImage> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await resolveSignedMealImageUrl(widget.imageUrl);
    if (mounted) setState(() => _resolvedUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedUrl == null) {
      return Shimmer.fromColors(
        baseColor: AppTheme.muted,
        highlightColor: AppTheme.background,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (_, _) => Shimmer.fromColors(
          baseColor: AppTheme.muted,
          highlightColor: AppTheme.background,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.muted,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: const Center(
            child: Text(
              '\u{1F372}',
              style: TextStyle(fontSize: AppTheme.fontSizeHeadingLG),
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _IngredientImage({this.imageUrl, this.size = 64});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && isValidImageUrl(imageUrl!)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => Shimmer.fromColors(
            baseColor: AppTheme.muted,
            highlightColor: AppTheme.background,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppTheme.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.muted,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text('\u{1F96C}', style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}
