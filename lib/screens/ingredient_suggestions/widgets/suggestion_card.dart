import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../models/ingredient_suggestion_group.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../config/constants.dart';
import '../../../utils/reduced_motion.dart';
import '../../../utils/url_utils.dart';
import 'ingredient_placeholder.dart';

class SuggestionCard extends StatelessWidget {
  final IngredientSuggestionGroup group;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const SuggestionCard({
    super.key,
    required this.group,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // The skipped ones („Passt nicht für mich") are left out.
    final replacements = group.visibleReplacements;
    return Dismissible(
      key: Key(group.ingredientId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: const Icon(Icons.close, color: AppTheme.mutedForeground),
      ),
      // Swiping is not the only way: a screen reader offers „Ausblenden".
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Ausblenden'): onDismiss,
        },
        child: BbCard(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IngredientAvatar(imageUrl: group.ingredientImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.ingredientName,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeSubtitle,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (group.isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSm,
                                  ),
                                ),
                                child: const Text(
                                  'Neu',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeSM,
                                    color: AppTheme.primaryForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        AppConstants.gap4,
                        Text(
                          'gefunden in ${group.mealCount} ${group.mealCount == 1 ? 'Mahlzeit' : 'Mahlzeiten'}',
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeCaption,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.muted,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              if (replacements.isNotEmpty) ...[
                AppConstants.gap12,
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: replacements.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final repl = replacements[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.beige,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusRound,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (repl.imageUrl != null &&
                                isHttpUrl(repl.imageUrl!)) ...[
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: repl.imageUrl!,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  placeholder: (context, _) =>
                                      ReducedMotion.shimmer(
                                        context,
                                        baseColor: AppTheme.muted,
                                        highlightColor: AppTheme.background,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                  errorWidget: (_, _, _) =>
                                      const IngredientPlaceholder(size: 24),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              repl.name,
                              style: const TextStyle(
                                fontSize: AppTheme.fontSizeCaptionLG,
                                color: AppTheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientAvatar extends StatelessWidget {
  final String? imageUrl;

  const _IngredientAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && isHttpUrl(imageUrl!)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, _) => ReducedMotion.shimmer(
            context,
            baseColor: AppTheme.muted,
            highlightColor: AppTheme.background,
            child: Container(
              width: 48,
              height: 48,
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

  Widget _fallback() => const IngredientPlaceholder(size: 48);
}
