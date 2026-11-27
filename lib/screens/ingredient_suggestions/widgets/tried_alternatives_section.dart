import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/alternative_choices_provider.dart';
import '../../../services/daily_review/daily_review_copy.dart';

/// „Probiere ich": the alternatives the user saved to try, newest first.
/// Absent without any.
class TriedAlternativesSection extends ConsumerWidget {
  const TriedAlternativesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tried = ref.watch(triedAlternativesProvider);
    if (tried.isEmpty) return const SizedBox.shrink();

    // Many rows scroll within a share of the screen, not push the list away.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Probiere ich',
            style: TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final c in tried)
                  Row(
                    key: ValueKey(c.id),
                    children: [
                      Expanded(
                        child: Text(
                          '${c.replacementName} statt ${c.ingredientName}',
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Nicht mehr merken',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await ref
                              .read(alternativeChoicesProvider.notifier)
                              .remove(c.id);
                          if (!ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(DailyReviewCopy.failed),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
