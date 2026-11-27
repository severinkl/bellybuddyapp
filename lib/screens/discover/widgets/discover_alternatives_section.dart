import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/ingredient_suggestion_group.dart';
import '../../../providers/plus_provider.dart';
import '../../../services/plus/plus_copy.dart';
import '../../../widgets/common/plus_locked_card.dart';
import 'discover_section.dart';

/// The newest [shown] suggestion groups (new first, then by their latest
/// meal) and „Alle ›"; none: a line and no link — while Belly Buddy Plus
/// is locked, the Plus note and a link to `/plus` instead.
class DiscoverAlternativesSection extends ConsumerWidget {
  const DiscoverAlternativesSection({
    super.key,
    required this.groups,
    required this.newCount,
    required this.onOpen,
  });

  /// The section, with its „Alle ›".
  static const sectionKey = Key('discover_alternatives');

  /// How many groups the section lists.
  static const shown = 3;

  final AsyncValue<List<IngredientSuggestionGroup>> groups;

  /// The „n neu" badge; none at 0.
  final int newCount;

  final VoidCallback onOpen;

  static List<IngredientSuggestionGroup> _newest(
    List<IngredientSuggestionGroup> groups,
  ) {
    final sorted = [...groups]
      ..sort(
        (a, b) => IngredientSuggestionGroup.compareNewFirst(
          a,
          b,
          latestMealFirst: true,
        ),
      );
    return sorted.take(shown).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plusLocked = ref.watch(plusLockedProvider);
    final list = groups.value;
    final hasAny = list != null && list.isNotEmpty;
    return DiscoverSection(
      key: sectionKey,
      title: 'Alternativen',
      badge: newCount > 0 ? '$newCount neu' : null,
      actions: [if (hasAny) DiscoverAllLink(onTap: onOpen)],
      child: switch (list) {
        null => DiscoverNote.pending(groups, 'Alternativen'),
        [] when plusLocked => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [DiscoverNote(PlusCopy.alternativesNote), PlusLink()],
        ),
        [] => const DiscoverNote(
          'Noch keine Alternativen – sie entstehen nach deinen Mahlzeiten.',
        ),
        final items => DiscoverListCard(
          onTap: onOpen,
          children: [
            for (final group in _newest(items)) _AlternativeRow(group: group),
          ],
        ),
      },
    );
  }
}

/// A suggestion group's ingredient and what can replace it, without the
/// ones that do not fit („Passt nicht für mich").
class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.group});

  final IngredientSuggestionGroup group;

  @override
  Widget build(BuildContext context) {
    final replacements = group.visibleReplacements
        .map((r) => r.name)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.ingredientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (replacements.isNotEmpty) ...[
            AppConstants.gap4,
            Text(
              'Stattdessen: $replacements',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
