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

/// Home's card on what the Buddy learns about the user's gut; a tap opens
/// the Muster page.
///
/// - Locked: how much is left until the first patterns, and both progress
///   bars (days with entries, gut-feeling entries).
/// - Unlocked, the insights' [Insights.pick]: the top „Fällt mir auf" item,
///   else what was often there on good days, else nothing yet; each with
///   „kein Befund".
///
/// Shows only [AsyncData]: while loading, after a failure, and while the
/// next user's insights load (the state then still holds the previous
/// user's value) the card is hidden.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insights});

  static const cardKey = Key('insight_card');

  final AsyncValue<Insights> insights;

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
    if (value == null) return const SizedBox.shrink();
    void open() => context.push(RoutePaths.patterns);
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
