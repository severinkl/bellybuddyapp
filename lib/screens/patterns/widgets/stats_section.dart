import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/pattern_stats.dart';
import '../../../providers/pattern_stats_provider.dart';
import '../../../services/insights/stats_copy.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/bb_tap_area.dart';
import '../../registration/widgets/step_field_label.dart';

/// Builds what sits at the end of a shown row (IA4: „Testen" or the
/// „getestet" badge); null for nothing.
typedef StatsRowTrailing = Widget? Function(StatItem item);

/// „Genauer hingeschaut": the 90-day comparison ([patternStatsProvider]).
/// FODMAP groups first, each with its ingredients indented under it, then
/// the loose ingredients, then „Bei dir unauffällig"; under them the
/// collapsed limits and the closing line. Not ready: how many rated days
/// there are. Failed: a line and „Nochmal versuchen". Locked by the server
/// (402) or signed out: nothing. Only built where the 30-day Muster show,
/// so Plus gating is the page's ([PatternsUnlocked]).
class StatsSection extends ConsumerWidget {
  const StatsSection({super.key, this.trailing, this.closingAction});

  /// Per shown row (groups and ingredients, not calm ones).
  final StatsRowTrailing? trailing;

  /// After the closing line („Testen", IA4); none when null.
  final Widget? closingAction;

  /// The row of the item of [kind] (`group` / `ingredient`) and [key].
  static Key rowKey(String kind, String key) =>
      ValueKey('stats_row_${kind}_$key');

  static const retryKey = Key('stats_retry');
  static const limitsKey = Key('stats_limits');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patternStatsProvider);
    if (state.isLocked) return const SizedBox.shrink();
    final Widget body;
    if (state.hasValue) {
      final stats = state.value;
      if (stats == null) return const SizedBox.shrink();
      body = stats.ready
          ? _Ready(
              stats: stats,
              trailing: trailing,
              closingAction: closingAction,
            )
          : _Line(StatsCopy.notReady(stats.ratedDays));
    } else if (state.hasError) {
      body = _Failed(
        onRetry: () => ref.read(patternStatsProvider.notifier).refresh(),
      );
    } else {
      // Loading: the header holds the place.
      body = const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepFieldLabel(StatsCopy.title),
        AppConstants.gap4,
        const Text(StatsCopy.subtitle, style: AppTheme.bodyMutedStyle),
        AppConstants.gap8,
        body,
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      BbCard(child: Text(text, style: AppTheme.bodyMutedStyle));
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: const Text(StatsCopy.error, style: AppTheme.bodyMutedStyle),
          ),
          TextButton(
            key: StatsSection.retryKey,
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: AppConstants.minTapSize,
              padding: EdgeInsets.zero,
            ),
            child: const Text(StatsCopy.retry),
          ),
        ],
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.stats,
    required this.trailing,
    required this.closingAction,
  });

  final PatternStats stats;
  final StatsRowTrailing? trailing;
  final Widget? closingAction;

  @override
  Widget build(BuildContext context) {
    final loose = stats.loose;
    final shown = [
      if (stats.groups.isNotEmpty)
        _Group(StatsCopy.groupsHeading, [
          for (final g in stats.groups) ...[
            _Row(g, trailing: trailing),
            for (final m in stats.membersOf(g))
              _Row(m, trailing: trailing, nested: true),
          ],
        ]),
      if (loose.isNotEmpty)
        _Group(StatsCopy.looseHeading, [
          for (final i in loose) _Row(i, trailing: trailing),
        ]),
      if (stats.calm.isNotEmpty)
        _Group(StatsCopy.calmHeading, [for (final c in stats.calm) _Calm(c)]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacing12,
      children: [
        if (shown.isEmpty) const _Line(StatsCopy.nothingShown) else ...shown,
        const _Limits(),
        if (closingAction case final action?)
          Wrap(
            spacing: AppConstants.spacingSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(StatsCopy.closing, style: AppTheme.bodyStyle),
              action,
            ],
          )
        else
          const Text(StatsCopy.closing, style: AppTheme.bodyStyle),
      ],
    );
  }
}

/// A sub-heading and its rows in a card.
class _Group extends StatelessWidget {
  const _Group(this.heading, this.rows);

  final String heading;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppConstants.spacing12,
        children: [
          Semantics(header: true, child: Text(heading, style: _headingStyle)),
          ...rows,
        ],
      ),
    );
  }

  static const _headingStyle = TextStyle(
    fontSize: AppTheme.fontSizeBodyLG,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );
}

/// Name and badge, then the counts line; read as one. A [nested] row (an
/// ingredient under its group) is indented.
class _Row extends StatelessWidget {
  const _Row(this.item, {required this.trailing, this.nested = false});

  final StatItem item;
  final StatsRowTrailing? trailing;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final end = trailing?.call(item);
    return Padding(
      key: StatsSection.rowKey(item.kind, item.key),
      padding: EdgeInsetsDirectional.only(
        start: nested ? AppConstants.spacingMd : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppConstants.spacingXs,
                children: [
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    runSpacing: AppConstants.spacingXs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.name, style: _nameStyle),
                      _Badge(item.level),
                    ],
                  ),
                  Text(StatsCopy.rowLine(item), style: AppTheme.bodyMutedStyle),
                ],
              ),
            ),
          ),
          if (end != null) ...[
            const SizedBox(width: AppConstants.spacingSm),
            // A long „getestet" badge wraps instead of squeezing the name.
            Flexible(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: end,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _nameStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    height: AppTheme.lineHeightSnug,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );
}

class _Calm extends StatelessWidget {
  const _Calm(this.item);

  final StatItem item;

  @override
  Widget build(BuildContext context) => Text(
    key: StatsSection.rowKey(item.kind, item.key),
    StatsCopy.calmLine(item),
    style: AppTheme.bodyStyle,
  );
}

/// The level's badge: strong dark, noticed filled, unsure outlined; each
/// with its word, so never colour-only.
class _Badge extends StatelessWidget {
  const _Badge(this.level);

  final StatLevel level;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (level) {
      StatLevel.strong => (
        AppTheme.statBadgeStrongFill,
        AppTheme.statBadgeStrongText,
      ),
      StatLevel.noticed => (AppTheme.muted, AppTheme.foreground),
      StatLevel.unsure ||
      StatLevel.calm => (AppTheme.card, AppTheme.mutedForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        StatsCopy.badge(level),
        style: TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

/// „Was dieser Vergleich nicht kann", collapsed; a disclosure button that
/// says whether it is open. The lines simply appear (no motion).
class _Limits extends StatefulWidget {
  const _Limits();

  @override
  State<_Limits> createState() => _LimitsState();
}

class _LimitsState extends State<_Limits> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BbTapArea(
          tapKey: StatsSection.limitsKey,
          expanded: _open,
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              const Expanded(
                child: Text(StatsCopy.limitsTitle, style: _titleStyle),
              ),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.mutedForeground,
              ),
            ],
          ),
        ),
        if (_open)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppConstants.spacingSm,
            children: [
              for (final line in StatsCopy.limits)
                Text(line, style: AppTheme.bodyMutedStyle),
            ],
          ),
      ],
    );
  }

  static const _titleStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );
}
