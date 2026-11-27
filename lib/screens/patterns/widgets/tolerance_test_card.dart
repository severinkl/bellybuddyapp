import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/tolerance_test.dart';
import '../../../providers/pattern_stats_provider.dart';
import '../../../providers/plus_provider.dart';
import '../../../providers/today_provider.dart';
import '../../../providers/tolerance_test_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/insights/test_copy.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/bb_tap_area.dart';
import '../tolerance_test_screen.dart';
import 'stats_section.dart';

/// The Muster page's Verträglichkeits-Test card, above „Genauer
/// hingeschaut": a running test („Tag 2 von 8" and its phase) or its result
/// (headline, conclusion and both notes, for the 14 days core sends it)
/// open the test page; a proposal („Magst du Zwiebel testen?") opens its
/// intro, only per [canOfferTest]. Nothing while restrictive without a test,
/// without anything to show, or while Plus is locked.
class ToleranceTestCard extends ConsumerWidget {
  const ToleranceTestCard({super.key});

  static const tapKey = Key('tolerance_test_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(plusLockedProvider)) return const SizedBox.shrink();
    final state = ref.watch(patternStatsProvider);
    if (!state.hasValue || state.isLocked) return const SizedBox.shrink();
    final stats = state.value;
    if (stats == null) return const SizedBox.shrink();
    final test = stats.test;
    final result = test?.result;

    final List<Widget> lines;
    Object? extra;
    if (test != null &&
        test.phase == TestPhase.done &&
        (result != null || test.isActive)) {
      // Active, over, without a result (should not happen): nothing, never
      // „Tag 9 von 8", and no proposal until it is completed.
      if (result == null) return const SizedBox.shrink();
      lines = [
        _title(TestCopy.title(test.subject)),
        Text(
          TestCopy.resultHeadline(test.subject, result),
          style: AppTheme.bodyStyle,
        ),
        Text(
          TestCopy.conclusion(result.outcome, test.subject),
          style: AppTheme.bodyStyle,
        ),
        const Text(TestCopy.notMedical, style: AppTheme.bodyMutedStyle),
        const Text(TestCopy.doctor, style: AppTheme.bodyMutedStyle),
      ];
    } else if (test != null && test.isActive) {
      final phase = TestCopy.phaseLine(test.phase, test.subject);
      lines = [
        _title(TestCopy.title(test.subject)),
        Text(
          test.dayIndex < 1
              ? TestCopy.startsOn(test.startsOn)
              : TestCopy.dayOf(test.dayIndex, test.totalDays),
          style: AppTheme.bodyStyle,
        ),
        if (phase != null) Text(phase, style: AppTheme.bodyMutedStyle),
      ];
    } else if (stats.proposal case final proposal?
        when ref.watch(canOfferTestProvider)) {
      lines = [
        const Text(TestCopy.pageTitle, style: AppTheme.bodyMutedStyle),
        _title(TestCopy.proposal(proposal)),
      ];
      extra = ToleranceTestProposed(proposal);
    } else {
      return const SizedBox.shrink();
    }
    // Its own gap below, so nothing is left when there is no card.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: _tap(context, extra, lines),
    );
  }

  static Widget _tap(BuildContext context, Object? extra, List<Widget> lines) {
    return BbTapArea(
      tapKey: tapKey,
      tapTarget: false,
      onTap: () => context.push(RoutePaths.toleranceTest, extra: extra),
      child: BbCard(
        color: AppTheme.primarySoft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppConstants.spacingXs,
                children: lines,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }

  static Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: AppTheme.fontSizeBodyLG,
      fontWeight: FontWeight.w600,
      color: AppTheme.foreground,
    ),
  );
}

/// „Genauer hingeschaut" with the test actions: a row whose subject was
/// tested in the last 60 days shows its „getestet" badge; otherwise, per
/// [canOfferTest], „Testen" (its intro); and the closing line gets
/// „Testen" (the proposal or the group picker, [ToleranceTestPick]).
class StatsSectionWithTests extends ConsumerWidget {
  const StatsSectionWithTests({super.key});

  static const closingTestKey = Key('stats_closing_test');

  /// The „Testen" button of the row [kind]/[key].
  static Key testKey(String kind, String key) =>
      ValueKey('stats_test_${kind}_$key');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(plusLockedProvider)) return const StatsSection();
    final stats = ref.watch(patternStatsProvider).value;
    final today = ref.watch(todayProvider);
    final canOffer = ref.watch(canOfferTestProvider);
    return StatsSection(
      trailing: (item) {
        final tested = stats?.testedFor(item.kind, item.key, today: today);
        if (tested != null) return TestedBadge(tested.outcome);
        if (!canOffer) return null;
        return _TestButton(
          tapKey: testKey(item.kind, item.key),
          semanticsLabel: TestCopy.testActionSemantics(item.name),
          onPressed: () => context.push(
            RoutePaths.toleranceTest,
            extra: TestSubject(item.kind, item.key, item.name),
          ),
        );
      },
      closingAction: canOffer
          ? _TestButton(
              tapKey: closingTestKey,
              onPressed: () => context.push(
                RoutePaths.toleranceTest,
                extra: const ToleranceTestPick(),
              ),
            )
          : null,
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.tapKey,
    required this.onPressed,
    this.semanticsLabel,
  });

  final Key tapKey;
  final VoidCallback onPressed;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => TextButton(
    key: tapKey,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: AppConstants.minTapSize,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingSm),
    ),
    child: Text(TestCopy.testAction, semanticsLabel: semanticsLabel),
  );
}

/// „getestet: deutlich schlechter" and the like, a pill on a stats row.
class TestedBadge extends StatelessWidget {
  const TestedBadge(this.outcome, {super.key});

  final TestOutcome outcome;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingSm,
      vertical: AppConstants.spacing2,
    ),
    decoration: BoxDecoration(
      color: AppTheme.muted,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
    ),
    child: Text(
      TestCopy.badge(outcome),
      style: const TextStyle(
        fontSize: AppTheme.fontSizeCaption,
        fontWeight: FontWeight.w600,
        color: AppTheme.foreground,
      ),
    ),
  );
}
