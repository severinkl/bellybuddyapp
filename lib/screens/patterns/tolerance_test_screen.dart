import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/insights.dart';
import '../../models/pattern_stats.dart';
import '../../models/tolerance_test.dart';
import '../../providers/pattern_stats_provider.dart';
import '../../providers/plus_provider.dart';
import '../../providers/today_provider.dart';
import '../../providers/tolerance_test_provider.dart';
import '../../router/route_names.dart';
import '../../services/insights/stats_copy.dart';
import '../../services/insights/test_copy.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/bb_tap_area.dart';
import 'widgets/day_class_look.dart';
import 'widgets/insight_calendar.dart';
import 'widgets/patterns_plus_locked.dart';

/// The `extra` of `/patterns/test` that asks for something new to test
/// (the proposal, else the group picker), never the last result
/// („Testen" under „Genauer hingeschaut").
class ToleranceTestPick {
  const ToleranceTestPick();
}

/// The `extra` of `/patterns/test` from a proposal (the Muster card, Home's
/// sheet): [subject]'s intro, started as `proposed`. A bare [TestSubject]
/// (a stats row, the picker, „Nochmal testen") starts as `picked`.
class ToleranceTestProposed {
  const ToleranceTestProposed(this.subject);

  final TestSubject subject;
}

/// The Verträglichkeits-Test (`/patterns/test`, spec §5.4/§5.6).
///
/// An active test always shows (running, or its result once past its
/// end). Otherwise: with a [TestSubject] or [ToleranceTestProposed] as
/// [extra] its intro; without one
/// the last result (completed within 14 days), else the proposal's intro,
/// else a picker of the six FODMAP groups ([ToleranceTestPick] skips the
/// last result). While restrictive, the restrictive text instead of intro
/// and picker. „Test starten" only per [canOfferTest].
///
/// While Plus is locked (or the server says so, 402) it shows the Muster
/// page's Plus lock instead. „Nochmal testen" and the picker replace the
/// page with the intro (never a stack of test pages).
class ToleranceTestScreen extends ConsumerStatefulWidget {
  const ToleranceTestScreen({super.key, this.extra});

  /// A [TestSubject], a [ToleranceTestProposed], a [ToleranceTestPick] or
  /// null.
  final Object? extra;

  static const startKey = Key('tolerance_test_start');
  static const stopKey = Key('tolerance_test_stop');
  static const retestKey = Key('tolerance_test_retest');
  static const markerKey = Key('tolerance_test_marker');

  /// The [i]-th day's dot (0-based).
  static Key dotKey(int i) => ValueKey('tolerance_test_day_$i');

  /// The picker's row of the group [key].
  static Key groupKey(String key) => ValueKey('tolerance_test_group_$key');

  @override
  ConsumerState<ToleranceTestScreen> createState() =>
      _ToleranceTestScreenState();
}

class _ToleranceTestScreenState extends ConsumerState<ToleranceTestScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    ref.read(patternStatsProvider.notifier).refreshOnOpen();
  }

  @override
  Widget build(BuildContext context) {
    final plusLocked = ref.watch(plusLockedProvider);
    final state = ref.watch(patternStatsProvider);
    final Widget body;
    if (plusLocked || state.isLocked) {
      body = _list([const PatternsPlusLocked()]);
    } else if (state.hasValue) {
      final stats = state.value;
      body = stats == null
          ? const SizedBox.shrink()
          : _list(_content(stats, canOffer: ref.watch(canOfferTestProvider)));
    } else if (state.hasError) {
      body = BbErrorState(
        message: StatsCopy.error,
        retryLabel: StatsCopy.retry,
        onRetry: () => ref.read(patternStatsProvider.notifier).refresh(),
      );
    } else {
      body = const BbLoadingState();
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(TestCopy.pageTitle),
        // A reminder opens it without a page below: back goes to Muster.
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(RoutePaths.patterns)),
      ),
      body: SafeArea(child: body),
    );
  }

  static Widget _list(List<Widget> children) => ListView(
    padding: AppConstants.paddingMd,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppConstants.spacing12,
        children: children,
      ),
    ],
  );

  List<Widget> _content(PatternStats stats, {required bool canOffer}) {
    final extra = widget.extra;
    // Where the intro came from decides the origin, never the value.
    final (TestSubject? subject, String origin) = switch (extra) {
      final TestSubject s => (s, 'picked'),
      ToleranceTestProposed(:final subject) => (subject, 'proposed'),
      _ => (stats.proposal, 'proposed'),
    };
    final hasSubject = extra is TestSubject || extra is ToleranceTestProposed;
    final test = stats.test;
    final shownTest =
        test != null &&
        (test.isActive ||
            (test.status == 'completed' &&
                !hasSubject &&
                extra is! ToleranceTestPick));
    if (shownTest) return _testView(test, canOffer: canOffer);
    if (stats.restrictive) return const [_Restrictive()];
    if (subject != null) {
      return _intro(stats, subject, origin: origin, canOffer: canOffer);
    }
    return _picker();
  }

  // -- Intro ----------------------------------------------------------------

  List<Widget> _intro(
    PatternStats stats,
    TestSubject s, {
    required String origin,
    required bool canOffer,
  }) {
    const leaveOut = ToleranceTestView.defaultLeaveOutDays;
    const reintro = ToleranceTestView.defaultReintroDays;
    final startsOn = addDays(ref.watch(todayProvider), 1);
    final foods = s.kind == 'group' ? _foodsOf(stats, s.key) : const <String>[];
    return [
      _Title(TestCopy.title(s)),
      Text(TestCopy.introBody(s, leaveOut, reintro), style: AppTheme.bodyStyle),
      Text(
        TestCopy.datesLine(startsOn, leaveOut, reintro),
        style: _strongStyle,
      ),
      if (foods.isNotEmpty)
        Text(TestCopy.groupFoods(s, foods), style: AppTheme.bodyStyle),
      const Text(TestCopy.doctor, style: AppTheme.bodyMutedStyle),
      if (canOffer)
        BbButton(
          tapKey: ToleranceTestScreen.startKey,
          label: TestCopy.startAction,
          isLoading: _starting,
          onPressed: () => _start(s, origin),
        ),
    ];
  }

  /// Up to five foods the user ate that carry the group [key]: the shown
  /// ingredients, then the calm ones, in the server's order.
  static List<String> _foodsOf(PatternStats stats, String key) => [
    for (final i in [...stats.ingredients, ...stats.calm])
      if (i.groups.contains(key)) i.name,
  ].take(5).toList();

  Future<void> _start(TestSubject s, String origin) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    final outcome = await startToleranceTest(ref, s, origin: origin);
    if (!mounted) return;
    setState(() => _starting = false);
    // A conflict reloaded the stats: the running test shows.
    if (outcome == StartOutcome.failed) {
      messenger.showSnackBar(
        const SnackBar(content: Text(TestCopy.startFailed)),
      );
    }
  }

  // -- Running test or result -------------------------------------------------

  List<Widget> _testView(ToleranceTestView t, {required bool canOffer}) {
    final s = t.subject;
    final result = t.result;
    final header = [
      _Title(TestCopy.title(s)),
      Text(
        TestCopy.datesLine(t.startsOn, t.leaveOutDays, t.reintroDays),
        style: AppTheme.bodyMutedStyle,
      ),
      _TestDays(test: t),
    ];
    if (t.phase == TestPhase.done && result != null) {
      final lines = TestCopy.resultLines(s, result);
      return [
        ...header,
        Text(lines.first, style: _strongStyle),
        for (final line in lines.skip(1))
          Text(
            line,
            style: line == TestCopy.notMedical || line == TestCopy.doctor
                ? AppTheme.bodyMutedStyle
                : AppTheme.bodyStyle,
          ),
        // Only once completed: an active test past its end blocks a start.
        if (result.outcome == TestOutcome.unclear &&
            t.status == 'completed' &&
            canOffer)
          BbButton(
            tapKey: ToleranceTestScreen.retestKey,
            label: TestCopy.retest,
            isOutlined: true,
            onPressed: () =>
                context.pushReplacement(RoutePaths.toleranceTest, extra: s),
          ),
      ];
    }
    final phase = TestCopy.phaseLine(t.phase, s);
    final notKept = t.days
        .where((d) => d.phase == TestPhase.leaveOut && d.exposed)
        .length;
    final notEaten = t.days
        .where(
          (d) =>
              d.phase == TestPhase.reintro &&
              !d.exposed &&
              d.dayClass != DayClass.none,
        )
        .length;
    return [
      ...header,
      Text(
        t.dayIndex < 1
            ? TestCopy.startsOn(t.startsOn)
            : TestCopy.dayOf(t.dayIndex, t.totalDays),
        style: _strongStyle,
      ),
      if (phase != null) Text(phase, style: AppTheme.bodyStyle),
      if (notKept > 0)
        Text(TestCopy.notKept(notKept, s), style: AppTheme.bodyMutedStyle),
      if (notEaten > 0)
        Text(TestCopy.notEaten(notEaten, s), style: AppTheme.bodyMutedStyle),
      if (t.isActive && t.phase != TestPhase.done)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: ToleranceTestScreen.stopKey,
            onPressed: () => _stop(t.id),
            style: TextButton.styleFrom(minimumSize: AppConstants.minTapSize),
            child: const Text(TestCopy.stopAction),
          ),
        ),
    ];
  }

  Future<void> _stop(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text(TestCopy.stopTitle),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppConstants.spacing12,
          children: [
            Text(TestCopy.stopBody, style: AppTheme.bodyStyle),
            Text(TestCopy.doctor, style: AppTheme.bodyMutedStyle),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(minimumSize: AppConstants.minTapSize),
            child: const Text(TestCopy.stopKeep),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              minimumSize: AppConstants.minTapSize,
            ),
            child: const Text(TestCopy.stopConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await stopToleranceTest(ref, id);
    } catch (_) {
      // Logged by the repository (by code only).
      messenger.showSnackBar(
        const SnackBar(content: Text(TestCopy.stopFailed)),
      );
    }
  }

  // -- Picker -----------------------------------------------------------------

  List<Widget> _picker() => [
    const _Title(TestCopy.pickerTitle),
    const Text(TestCopy.pickerLine, style: AppTheme.bodyMutedStyle),
    BbCard(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in TestCopy.groups)
            BbTapArea(
              tapKey: ToleranceTestScreen.groupKey(g.key),
              onTap: () =>
                  context.pushReplacement(RoutePaths.toleranceTest, extra: g),
              child: Row(
                children: [
                  Expanded(child: Text(g.name, style: _strongStyle)),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  ];

  static const _strongStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    height: AppTheme.lineHeightSnug,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AppTheme.fontSizeTitle,
        fontWeight: FontWeight.w700,
        color: AppTheme.foreground,
      ),
    ),
  );
}

class _Restrictive extends StatelessWidget {
  const _Restrictive();

  @override
  Widget build(BuildContext context) => const BbCard(
    child: Text(TestCopy.restrictive, style: AppTheme.bodyStyle),
  );
}

/// One dot per test day, then the legend. A day so far shows its gut
/// feeling as the Muster calendar does (an icon on a tint), a day without
/// one is grey, a day to come an outline; a leave-out day with the subject
/// („nicht eingehalten") or a rated reintroduction day without it („nicht
/// gegessen") carries a small marker. Each dot is read as „26. Nov:
/// schwer, nicht eingehalten".
class _TestDays extends StatelessWidget {
  const _TestDays({required this.test});

  final ToleranceTestView test;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in test.days) d.day: d};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacingSm,
      children: [
        Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: [
            for (var i = 0; i < test.totalDays; i++)
              _dot(i, addDays(test.startsOn, i), byDay),
          ],
        ),
        const _Legend(),
      ],
    );
  }

  Widget _dot(int i, DateTime day, Map<DateTime, TestDayView> byDay) {
    final d = byDay[day];
    final look = d == null ? null : dayClassLook(d.dayClass);
    final marked =
        d != null &&
        switch (d.phase) {
          TestPhase.leaveOut => d.exposed,
          TestPhase.reintro => !d.exposed && d.dayClass != DayClass.none,
          TestPhase.done => false,
        };
    return Semantics(
      key: ToleranceTestScreen.dotKey(i),
      container: true,
      label: d == null
          ? TestCopy.openDaySemantics(day)
          : TestCopy.daySemantics(d),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppConstants.testDayDotSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d == null ? null : look?.fill ?? AppTheme.muted,
                  border: d == null || look == null ? dayNoneBorder : null,
                ),
                child: look == null
                    ? null
                    : Icon(
                        look.icon,
                        size: AppConstants.iconSizeXs,
                        color: look.color,
                      ),
              ),
            ),
            if (marked)
              const PositionedDirectional(
                end: 0,
                bottom: 0,
                child: _Marker(key: ToleranceTestScreen.markerKey),
              ),
          ],
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: AppConstants.testDayMarkerSize,
    height: AppConstants.testDayMarkerSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppTheme.foreground,
      border: Border.all(color: AppTheme.background),
    ),
  );
}

/// „gut · mittel · schwer · kein Eintrag · noch offen · nicht eingehalten /
/// nicht gegessen", each with its mark; the dots say it all to a screen
/// reader, so the legend is excluded.
class _Legend extends StatelessWidget {
  const _Legend();

  static Widget _circle({Color? fill}) => Container(
    width: AppConstants.iconSizeXs,
    height: AppConstants.iconSizeXs,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: dayNoneBorder,
    ),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DayClassLegend(
      noneMark: _circle(fill: AppTheme.muted),
      extra: [
        (mark: _circle(), label: TestCopy.legendOpen),
        (
          mark: const SizedBox.square(
            dimension: AppConstants.iconSizeXs,
            child: Center(child: _Marker()),
          ),
          label: TestCopy.legendNotKept,
        ),
      ],
    ),
  );
}
