import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/alternative_choice.dart';
import '../../../providers/alternative_choices_provider.dart';
import '../../../providers/daily_review_provider.dart';
import '../../../providers/ingredient_suggestion_provider.dart';
import '../../../router/route_names.dart';
import '../../../router/tracker_routes.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../services/daily_review/daily_review_copy.dart';
import '../../../services/daily_review/daily_review_rules.dart';
import '../../../utils/gut_feeling_rating.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_card.dart';

/// Home's daily review ([dailyReviewProvider]), spec §4.3: the title with
/// „×", the day (meals, the last gut feeling or the ask to log one), the
/// extras, then the alternative („Probiere ich" / „Passt nicht für mich"),
/// the neutral line, or — locked — the hint without names (with a pick)
/// or the Plus line (without one); nothing of it while it still loads.
///
/// Nothing while there is no review. Each time it becomes visible (a Home
/// visit: `TickerMode` on) it refreshes the suggestions, so the last meal's
/// analysis is in. „Probiere ich" stored, the card says so for the rest of
/// its life (Home keys it by the review day).
class DailyReviewCard extends ConsumerStatefulWidget {
  const DailyReviewCard({super.key});

  static const cardKey = Key('daily_review_card');
  static const closeKey = Key('daily_review_close');
  static const tryKey = Key('daily_review_try');
  static const skipKey = Key('daily_review_skip');
  static const savedOpenKey = Key('daily_review_saved_open');
  static const gutAskKey = Key('daily_review_gut_ask');
  static const upsellKey = Key('daily_review_upsell');

  @override
  ConsumerState<DailyReviewCard> createState() => _DailyReviewCardState();
}

class _DailyReviewCardState extends ConsumerState<DailyReviewCard> {
  /// `TickerMode` as last seen (false until the first dependency update).
  bool _visible = false;

  /// The pick being stored: shown (buttons off) until the write is done,
  /// while the provider may already have moved on to the next.
  AlternativePick? _pending;
  AlternativeChoiceKind? _pendingKind;

  /// „Probiere ich" was stored.
  bool _saved = false;

  static const _titleStyle = TextStyle(
    fontSize: AppTheme.fontSizeSubtitleLG,
    fontWeight: FontWeight.w700,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.foreground,
  );

  static const _lineStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    height: AppTheme.lineHeightBody,
    color: AppTheme.foreground,
  );

  static const _captionStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      // Not during a build: the provider's state changes as it loads.
      Future.microtask(() {
        if (mounted) {
          unawaited(
            ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
          );
        }
      });
    }
  }

  Future<void> _choose(AlternativePick pick, AlternativeChoiceKind kind) async {
    if (_pending != null) return;
    setState(() {
      _pending = pick;
      _pendingKind = kind;
    });
    final ok = await ref
        .read(alternativeChoicesProvider.notifier)
        .choose(
          ingredientId: pick.group.ingredientId,
          ingredientName: pick.group.ingredientName,
          replacement: pick.replacement,
          kind: kind,
        );
    if (!mounted) return;
    setState(() {
      _pending = null;
      _pendingKind = null;
      if (ok && kind == AlternativeChoiceKind.tryIt) _saved = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(DailyReviewCopy.failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(dailyReviewProvider);
    if (review == null) return const SizedBox.shrink();
    final yesterday = review.day.yesterday;
    final upsellRoute = ref.watch(dailyReviewUpsellRouteProvider);

    Widget line(String text, {TextStyle style = _lineStyle}) =>
        Text(text, style: style);

    Widget textButton(Key key, String label, VoidCallback onPressed) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(key: key, onPressed: onPressed, child: Text(label)),
    );

    final lastGut = review.lastGut;
    final day = <Widget>[
      line(DailyReviewCopy.meals(review.meals, yesterday: yesterday)),
      if (lastGut != null) ...[
        line(DailyReviewCopy.gut(lastGut)),
        if (lastGut == GutFeelingRatingLevel.schlecht)
          line(DailyReviewCopy.gutHard),
      ] else if (!yesterday) ...[
        line(DailyReviewCopy.gutAsk),
        textButton(
          DailyReviewCard.gutAskKey,
          DailyReviewCopy.gutAskButton,
          () => openTracker(context, CareNeed.gutFeeling),
        ),
      ],
    ];

    final extras = [
      for (final extra in review.extras)
        switch (extra.route) {
          null => line(extra.text),
          final route => InkWell(
            onTap: () => context.push(route),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: line(extra.text),
          ),
        },
    ];

    final alternative = _alternative(review, upsellRoute, line, textButton);

    return BbCard(
      key: DailyReviewCard.cardKey,
      color: AppTheme.beige,
      showBorder: false,
      radius: AppConstants.radiusRound,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppConstants.spacingMd,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
        AppConstants.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DailyReviewCopy.title(review.day),
                  style: _titleStyle,
                ),
              ),
              IconButton(
                key: DailyReviewCard.closeKey,
                tooltip: DailyReviewCopy.close,
                icon: const Icon(
                  Icons.close,
                  size: AppConstants.iconSizeClose,
                  color: AppTheme.mutedForeground,
                ),
                onPressed: () => ref
                    .read(dailyReviewClosedProvider.notifier)
                    .close(review.day.day),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppConstants.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...day,
                if (extras.isNotEmpty) ...[AppConstants.gap8, ...extras],
                if (alternative.isNotEmpty) ...[
                  AppConstants.gap12,
                  ...alternative,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _alternative(
    DailyReview review,
    String? upsellRoute,
    Widget Function(String, {TextStyle style}) line,
    Widget Function(Key, String, VoidCallback) textButton,
  ) {
    final yesterday = review.day.yesterday;
    if (_saved) {
      return [
        line(DailyReviewCopy.saved),
        textButton(
          DailyReviewCard.savedOpenKey,
          DailyReviewCopy.savedOpen,
          () => context.push(RoutePaths.ingredientSuggestions),
        ),
      ];
    }
    final pick = _pending ?? review.alternative;
    // Still loading: nothing yet, no claim to take back.
    if (pick == null && review.alternativePending) return const [];
    if (review.alternativeLocked) {
      return [
        line(
          pick == null
              ? DailyReviewCopy.lockedNoPick
              : DailyReviewCopy.locked(yesterday: yesterday),
        ),
        if (upsellRoute != null)
          textButton(
            DailyReviewCard.upsellKey,
            DailyReviewCopy.upsell,
            () => context.push(upsellRoute),
          ),
      ];
    }
    if (pick == null) return [line(DailyReviewCopy.none(yesterday: yesterday))];
    final busy = _pending != null;
    return [
      line(
        DailyReviewCopy.alternative(
          pick.group.ingredientName,
          pick.replacement.name,
          yesterday: yesterday,
        ),
      ),
      if (pick.recentMeals >= 2) ...[
        AppConstants.gap4,
        line(
          DailyReviewCopy.recent(pick.group.ingredientName, pick.recentMeals),
          style: _captionStyle,
        ),
      ],
      AppConstants.gap12,
      BbButton(
        tapKey: DailyReviewCard.tryKey,
        label: DailyReviewCopy.tryIt,
        isLoading: _pendingKind == AlternativeChoiceKind.tryIt,
        onPressed: busy
            ? null
            : () => _choose(pick, AlternativeChoiceKind.tryIt),
      ),
      Center(
        child: TextButton(
          key: DailyReviewCard.skipKey,
          onPressed: busy
              ? null
              : () => _choose(pick, AlternativeChoiceKind.skip),
          child: const Text(DailyReviewCopy.skip),
        ),
      ),
    ];
  }
}
