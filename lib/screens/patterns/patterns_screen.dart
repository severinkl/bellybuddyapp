import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/insights_provider.dart';
import '../../router/route_names.dart';
import '../../services/insights/insight_copy.dart';
import '../../widgets/common/bb_async_state.dart';
import 'widgets/patterns_locked.dart';
import 'widgets/patterns_unlocked.dart';

/// The Muster page behind Home's insight card (`/patterns`): what the last
/// 30 days of entries show. Locked until the first patterns unlock.
///
/// Shows only [AsyncData]: loading (also while the next user's insights
/// load) is [BbLoadingState], a failure [BbErrorState] with a retry. Pull to
/// refresh. Opened without a page below (a cold start on `/patterns`), back
/// goes Home.
class PatternsScreen extends ConsumerWidget {
  const PatternsScreen({super.key});

  static const _footerStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(insightsProvider.notifier);
    final body = ref
        .watch(insightsProvider)
        .when(
          loading: () => const BbLoadingState(),
          error: (_, _) => BbErrorState(
            message: InsightCopy.loadError,
            retryLabel: InsightCopy.retry,
            onRetry: notifier.refresh,
          ),
          data: (insights) => RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppConstants.paddingMd,
              children: [
                if (insights.unlocked)
                  PatternsUnlocked(insights: insights)
                else
                  PatternsLocked(progress: insights.progress),
                AppConstants.gap24,
                const Text(InsightCopy.footer, style: _footerStyle),
                if (insights.unlocked) ...[
                  AppConstants.gap4,
                  const Text(InsightCopy.dayDefinitions, style: _footerStyle),
                ],
              ],
            ),
          ),
        );
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(InsightCopy.patternsTitle),
        // Pushed from Home, the default back arrow pops.
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(RoutePaths.dashboard)),
      ),
      body: SafeArea(child: body),
    );
  }
}
