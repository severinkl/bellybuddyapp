import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_progress.dart';
import '../../../models/insights.dart';
import '../../../router/route_names.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/insight_progress_row.dart';
import '../../registration/widgets/step_field_label.dart';
import 'journey_dots.dart';

/// Home's card on what the Buddy learns about the user's gut; a tap opens
/// the Muster page (once: a double tap doesn't push it twice).
///
/// - Locked, for a user on the first-patterns [journey]: the Buddy's line,
///   the 7 [JourneyDots], the [journeyReward] (Stage 3's slot) and the day
///   and Bauchgefühl counters.
/// - Locked, otherwise: how much is left until the first patterns, and both
///   progress bars (days with entries, gut-feeling entries). Hidden while
///   [journey] is still undecided (null).
/// - Unlocked, the insights' [Insights.pick]: the top „Fällt mir auf" item,
///   else what was often there on good days, else nothing yet; each with
///   „kein Befund".
///
/// Shows only [AsyncData]: while loading, after a failure, and while the
/// next user's insights load (the state then still holds the previous
/// user's value) the card is hidden.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insights,
    this.journey,
    this.journeyReward,
  });

  static const cardKey = Key('insight_card');

  final AsyncValue<Insights> insights;

  /// Whether this user sees the journey while locked; null: undecided.
  final bool? journey;

  /// Under the dots of the journey.
  final Widget? journeyReward;

  static const _padding = EdgeInsets.fromLTRB(
    AppConstants.spacingMd,
    AppConstants.spacing14,
    AppConstants.spacingMd,
    AppConstants.spacingMd,
  );

  @override
  Widget build(BuildContext context) {
    final value = switch (insights) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (value == null || (!value.unlocked && journey == null)) {
      return const SizedBox.shrink();
    }
    void open() {
      final router = GoRouter.of(context);
      // Already on top: the second tap of a double tap, both before the
      // next frame (e.g. a slow one), so before the page covered the card.
      if (router.state.uri.path == RoutePaths.patterns) return;
      router.push(RoutePaths.patterns);
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: InsightCopy.openPatterns,
        onTap: open,
        child: BbCard(
          key: cardKey,
          color: AppTheme.beige,
          showBorder: false,
          radius: AppConstants.radiusRound,
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: open,
            // The button above speaks for it.
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: Padding(
              padding: _padding,
              child: value.unlocked
                  ? _Unlocked(value.pick)
                  : journey == true
                  ? _Journey(value, reward: journeyReward)
                  : _Locked(value.progress),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header with the link to the Muster page, the Buddy's [line], then
/// [below] it.
class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.line,
    required this.below,
    this.locked = false,
  });

  final String title;
  final String line;
  final List<Widget> below;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (locked) ...[
              const Icon(
                Icons.lock_outline,
                size: AppConstants.iconSizeXs,
                color: AppTheme.mutedForeground,
              ),
              const SizedBox(width: AppConstants.spacing6),
            ],
            Expanded(
              child: Text(
                title.toUpperCase(),
                semanticsLabel: title,
                style: StepFieldLabel.style,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            // The card's button label („Muster ansehen") says it.
            ExcludeSemantics(
              child: Text(
                InsightCopy.patternsLink.toUpperCase(),
                style: StepFieldLabel.style,
              ),
            ),
          ],
        ),
        AppConstants.gap8,
        Text(
          line,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeSubtitleLG,
            fontWeight: FontWeight.w700,
            height: AppTheme.lineHeightSnug,
            color: AppTheme.foreground,
          ),
        ),
        ...below,
      ],
    );
  }
}

/// How much is left until the first patterns, over both progress bars.
class _Locked extends StatelessWidget {
  const _Locked(this.progress);

  final InsightProgress progress;

  @override
  Widget build(BuildContext context) {
    return _Content(
      title: InsightCopy.learningTitle,
      line: InsightCopy.lockedLine(progress),
      locked: true,
      below: [AppConstants.gap12, InsightProgressBars(progress)],
    );
  }
}

/// The first 7 days: the Buddy's line, the dots, [reward], the counters.
class _Journey extends StatelessWidget {
  const _Journey(this.insights, {this.reward});

  final Insights insights;
  final Widget? reward;

  static const _counterStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  /// „2 von 7 Tagen" with its number in w600.
  Widget _counter(String text) {
    final split = text.indexOf(' von ');
    // The number before „ von ", or after „Bauchgefühl ".
    final start = text.lastIndexOf(' ', split - 1) + 1;
    final end = split + ' von '.length + 1;
    return Text.rich(
      TextSpan(
        style: _counterStyle,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = insights.progress;
    return _Content(
      title: InsightCopy.learningTitle,
      line: InsightCopy.journeyLine(progress),
      locked: true,
      below: [
        AppConstants.gap12,
        JourneyDots(days: insights.journey),
        if (reward != null) ...[AppConstants.gap8, reward!],
        AppConstants.gap8,
        Wrap(
          spacing: AppConstants.spacingMd,
          runSpacing: AppConstants.spacingXs,
          children: [
            _counter(InsightCopy.journeyDays(progress)),
            _counter(InsightCopy.journeyGutFeelings(progress)),
          ],
        ),
      ],
    );
  }
}

/// The Home [pick], its counts and „kein Befund".
class _Unlocked extends StatelessWidget {
  const _Unlocked(this.pick);

  final InsightPick pick;

  static const _metaStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context) {
    final (title, line, counts) = switch (pick) {
      NoticedPick(:final noticed) => (
        InsightCopy.noticedTitle,
        InsightCopy.noticedHeadline(noticed),
        InsightCopy.noticedGood(noticed),
      ),
      GoodDaysPick(:final goodDays) => (
        InsightCopy.goodDaysTitle,
        InsightCopy.goodDaysLine(goodDays),
        InsightCopy.goodDaysSub(goodDays),
      ),
      NothingYetPick() => (
        InsightCopy.learningTitle,
        InsightCopy.nothingYet,
        null,
      ),
    };
    return _Content(
      title: title,
      line: line,
      below: [
        AppConstants.gap8,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (counts == null)
              const Spacer()
            else
              Expanded(child: Text(counts, style: _metaStyle)),
            const SizedBox(width: AppConstants.spacing10),
            Text(
              InsightCopy.noFinding,
              style: _metaStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
