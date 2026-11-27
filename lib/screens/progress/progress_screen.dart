import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/progress.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/progress_provider.dart';
import '../../router/route_names.dart';
import '../../router/tracker_routes.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/insights/insight_copy.dart';
import '../../services/progress/progress_copy.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/progress_summary.dart';
import 'widgets/progress_weeks.dart';
import 'widgets/symptom_trend.dart';

/// „Dein Verlauf" (`/progress`): the last 12 Monday weeks at a glance, from
/// Ich and the Muster page. Free: not behind the Plus gate.
///
/// Reads [progressProvider] as its doc says: an error is [BbErrorState]
/// with a retry; a reload after a user change is [BbLoadingState] (its
/// value is the previous user's); otherwise the value, kept while an entry
/// write or a new day refetches. Pull to refresh. Opened without a page
/// below, back goes to Ich.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static const emptyKey = Key('progress_empty');

  /// A week's row, by its Monday.
  static Key weekKey(DateTime monday) => ProgressWeeks.weekKey(monday);

  static const _footerStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(progressProvider.notifier);
    final state = ref.watch(progressProvider);
    final progress = state.value;
    final Widget body;
    if (state.hasError) {
      body = BbErrorState(
        message: ProgressCopy.loadError,
        retryLabel: ProgressCopy.retry,
        onRetry: notifier.refresh,
      );
    } else if (state.isReloading || progress == null) {
      // Signed out there is nothing to show; the router leaves anyway.
      body = const BbLoadingState();
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppConstants.paddingMd,
          children: progress.isEmpty
              ? const [_Empty()]
              : _page(
                  progress,
                  // The Buddy's streak, as on Home (none while it loads).
                  currentStreak: ref.watch(buddyProvider).value?.streak ?? 0,
                  today: ref.read(buddyClockProvider)(),
                ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(ProgressCopy.title),
        // Pushed from Ich or the Muster page, the default back arrow pops.
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(RoutePaths.me)),
      ),
      body: SafeArea(child: body),
    );
  }

  static List<Widget> _page(
    Progress progress, {
    required int currentStreak,
    required DateTime today,
  }) => [
    ProgressSummary(progress: progress, currentStreak: currentStreak),
    AppConstants.gap24,
    ProgressWeeks(weeks: progress.weeks, today: today),
    AppConstants.gap24,
    if (progress.showTrend)
      SymptomTrend(weeks: progress.weeks)
    else ...[
      Semantics(
        header: true,
        child: const Text(
          ProgressCopy.trendTitle,
          style: AppTheme.bodyMutedStyle,
        ),
      ),
      AppConstants.gap8,
      const Text(ProgressCopy.trendTooFew, style: AppTheme.bodyMutedStyle),
    ],
    AppConstants.gap24,
    const Text(InsightCopy.footer, style: _footerStyle),
    AppConstants.gap4,
    const Text(InsightCopy.dayDefinitions, style: _footerStyle),
  ];
}

/// No entry in the window yet: the Buddy and the way to the first one.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ProgressScreen.emptyKey,
      children: [
        AppConstants.gap24,
        const MascotImage(
          assetPath: AppConstants.mascotClueless,
          width: AppConstants.progressEmptyBuddySize,
          height: AppConstants.progressEmptyBuddySize,
        ),
        AppConstants.gap16,
        Semantics(
          header: true,
          child: const Text(
            ProgressCopy.emptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
        ),
        AppConstants.gap8,
        const Text(
          ProgressCopy.emptyBody,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMutedStyle,
        ),
        AppConstants.gap24,
        BbButton(
          label: ProgressCopy.emptyAction,
          onPressed: () => openTracker(context, CareNeed.gutFeeling),
        ),
      ],
    );
  }
}
