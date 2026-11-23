import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/insights.dart';
import '../../providers/insights_provider.dart';
import '../../services/insights/insight_copy.dart';
import 'widgets/patterns_locked.dart';

/// The Muster page behind Home's insight card (`/patterns`): what the last
/// 30 days of entries show. Locked until the first patterns unlock.
///
/// Shows only [AsyncData]: loading (also while the next user's insights
/// load) is a spinner, a failure offers a retry. Pull to refresh.
class PatternsScreen extends ConsumerWidget {
  const PatternsScreen({super.key});

  static const title = 'Muster';
  static const errorText = 'Muster konnten nicht geladen werden.';
  static const retryLabel = 'Nochmal versuchen';
  static const footer =
      'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(insightsProvider.notifier);
    final body = ref
        .watch(insightsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(errorText, textAlign: TextAlign.center),
                TextButton(
                  onPressed: notifier.refresh,
                  child: const Text(retryLabel),
                ),
              ],
            ),
          ),
          data: (insights) => RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppConstants.paddingMd,
              children: [
                if (insights.progress.unlocked)
                  _UnlockedPlaceholder(insights)
                else
                  PatternsLocked(progress: insights.progress),
                AppConstants.gap24,
                const Text(
                  footer,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    height: AppTheme.lineHeightSnug,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(title),
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Stands in until the unlocked page lands: the observations as rows.
class _UnlockedPlaceholder extends StatelessWidget {
  const _UnlockedPlaceholder(this.insights);

  final Insights insights;

  @override
  Widget build(BuildContext context) {
    final noticed = insights.noticed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (noticed.isEmpty)
          const Text(InsightCopy.nothingYet)
        else
          for (final n in noticed) ...[
            Text(InsightCopy.noticedRow(n)),
            AppConstants.gap8,
          ],
      ],
    );
  }
}
