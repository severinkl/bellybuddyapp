import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../models/ingredient_suggestion_group.dart';
import '../../../config/constants.dart';
import '../../../utils/reduced_motion.dart';
import '../../../models/alternative_choice.dart';
import '../../../models/ranked_replacement.dart';
import '../../../providers/ingredient_suggestion_provider.dart';
import '../../../providers/plus_provider.dart';
import '../../../repositories/meal_media_repository.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/common/bb_sheet_messenger.dart';
import 'alternative_feedback_sheet.dart';
import 'ingredient_placeholder.dart';

/// A suggestion group in detail: the ingredient, its meals and its
/// alternatives, live from [ingredientSuggestionProvider] (a verdict ranks
/// them again at once). Tapping an alternative opens its verdict sheet,
/// behind the Plus lock like the Alternativen themselves.
class SuggestionDetailModal extends ConsumerWidget {
  final IngredientSuggestionGroup group;

  const SuggestionDetailModal({super.key, required this.group});

  /// The row of the alternatives that are not skipped.
  static const mainRowKey = Key('suggestion_detail_alternatives');

  /// The row under „Passt nicht für mich".
  static const skippedRowKey = Key('suggestion_detail_skipped');

  /// The tile of the replacement [id].
  static Key tileKey(String id) => Key('suggestion_detail_tile_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(ingredientSuggestionProvider).value;
    final live =
        groups
            ?.where((g) => g.ingredientId == group.ingredientId)
            .firstOrNull ??
        group;
    final visible = live.visibleReplacements;
    final skipped = [
      for (final r in live.replacements)
        if (r.skipped) r,
    ];
    final canRate = !ref.watch(plusLockedProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      // The verdict sheet's failure SnackBar shows in the modal.
      builder: (context, scrollController) => BbSheetMessenger(
        child: _content(
          context,
          live,
          visible,
          skipped,
          canRate,
          scrollController,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    IngredientSuggestionGroup live,
    List<RankedReplacement> visible,
    List<RankedReplacement> skipped,
    bool canRate,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with image and name
          Row(
            children: [
              _IngredientImage(imageUrl: live.ingredientImageUrl),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(
                  live.ingredientName,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitleLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
            ],
          ),
          AppConstants.gap20,

          // Helptext info box
          if (live.helptext != null && live.helptext!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: AppConstants.paddingMd,
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: AppConstants.spacing12),
                  Expanded(
                    child: Text(
                      live.helptext!,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: AppTheme.foreground,
                        height: AppTheme.lineHeightBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppConstants.gap20,
          ],

          // Meals section
          if (live.meals.isNotEmpty) ...[
            Text(
              'Gefunden in ${live.mealCount} ${live.mealCount == 1 ? 'Mahlzeit' : 'Mahlzeiten'}',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap12,
            ...live.meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      if (meal.imageUrl != null) ...[
                        _MealImage(imageUrl: meal.imageUrl!),
                        const SizedBox(width: AppConstants.spacing12),
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
                            const SizedBox(height: AppConstants.spacing2),
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

          // Alternatives: the ones that fit or may, then those that do
          // not under their own heading, dimmed.
          if (visible.isNotEmpty) ...[
            const _SectionTitle('Alternativen'),
            AppConstants.gap12,
            _AlternativeRow(
              key: mainRowKey,
              group: live,
              replacements: visible,
              canRate: canRate,
            ),
            AppConstants.gap12,
          ],
          if (skipped.isNotEmpty) ...[
            const _SectionTitle(AlternativeVerdictCopy.skip),
            AppConstants.gap12,
            _AlternativeRow(
              key: skippedRowKey,
              group: live,
              replacements: skipped,
              canRate: canRate,
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
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AppTheme.fontSizeSubtitle,
        fontWeight: FontWeight.w600,
        color: AppTheme.foreground,
      ),
    ),
  );
}

/// A horizontal row of alternative tiles.
class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    super.key,
    required this.group,
    required this.replacements,
    required this.canRate,
  });

  final IngredientSuggestionGroup group;
  final List<RankedReplacement> replacements;
  final bool canRate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.alternativeTileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: replacements.length,
        separatorBuilder: (c, i) =>
            const SizedBox(width: AppConstants.spacing12),
        itemBuilder: (context, index) => _AlternativeTile(
          group: group,
          replacement: replacements[index],
          canRate: canRate,
        ),
      ),
    );
  }
}

/// An alternative: its picture and name; „Passt für mich" adds a check,
/// „Passt nicht für mich" dims the picture. The verdict is also its
/// semantics value, so it is never told by look alone.
class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.group,
    required this.replacement,
    required this.canRate,
  });

  final IngredientSuggestionGroup group;
  final RankedReplacement replacement;
  final bool canRate;

  @override
  Widget build(BuildContext context) {
    final verdict = replacement.verdict;
    final image = _IngredientImage(
      imageUrl: replacement.imageUrl,
      size: AppConstants.alternativeTileImage,
    );
    void open() => showAlternativeFeedbackSheet(
      context,
      group: group,
      replacement: replacement.replacement,
    );
    return Semantics(
      key: SuggestionDetailModal.tileKey(replacement.id),
      container: true,
      button: canRate,
      label: replacement.name,
      value: verdict == null ? null : AlternativeVerdictCopy.of(verdict),
      excludeSemantics: true,
      onTap: canRate ? open : null,
      child: InkWell(
        onTap: canRate ? open : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: SizedBox(
          width: AppConstants.alternativeTileWidth,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (replacement.skipped)
                    Opacity(
                      opacity: AppConstants.skippedAlternativeOpacity,
                      child: image,
                    )
                  else
                    image,
                  if (verdict == AlternativeChoiceKind.fits)
                    const PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: AppConstants.iconSizeSm,
                          color: AppTheme.alternativeFitsCheck,
                        ),
                      ),
                    ),
                ],
              ),
              AppConstants.gap6,
              Text(
                replacement.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: replacement.skipped
                      ? AppTheme.mutedForeground
                      : AppTheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealImage extends ConsumerStatefulWidget {
  final String imageUrl;

  const _MealImage({required this.imageUrl});

  @override
  ConsumerState<_MealImage> createState() => _MealImageState();
}

class _MealImageState extends ConsumerState<_MealImage> {
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
      return ReducedMotion.shimmer(
        context,
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
        placeholder: (context, _) => ReducedMotion.shimmer(
          context,
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
    if (imageUrl != null && isHttpUrl(imageUrl!)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, _) => ReducedMotion.shimmer(
            context,
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

  Widget _fallback() => IngredientPlaceholder(size: size);
}
