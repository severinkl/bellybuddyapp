import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/dietitian_tip.dart';
import '../../../providers/buddy_provider.dart';
import '../../../providers/dietitian_tips_provider.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_card.dart';
import 'discover_section.dart';

final _day = DateFormat('d. MMM', 'de_DE');

/// How many older tips show before „Alle anzeigen".
const _olderShown = 5;

/// „JB" for „Julia Berger": the first letters of the first and the last
/// word; „?" for a blank name.
String tipInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  String first(String w) => String.fromCharCode(w.runes.first).toUpperCase();
  if (words.length == 1) return first(words.first);
  return first(words.first) + first(words.last);
}

/// „heute, 09:12", „gestern, 09:12" or „19. Nov., 09:12". [at] is a real
/// instant, shown in local time; [now] is the app's clock.
String tipWhen(DateTime at, DateTime now) =>
    formatRecentDayTime(at.toLocal(), now);

/// Entdecken's „Von deiner Berater:in": the tips the user's dietitians
/// sent, the newest large, older ones as a short list. Absent without a
/// tip (and while loading or failed). Once actually visible (its tickers
/// run: not an offstage shell branch, not under a pushed route or the
/// splash) it stamps the new tips seen, once per load; the „Neu" badge
/// stays until the next load.
class DietitianTipsSection extends ConsumerStatefulWidget {
  const DietitianTipsSection({super.key});

  static const sectionKey = Key('dietitian-tips-section');

  /// What a failing „Probiere ich" or „Entfernen" says.
  static const failedLine =
      'Das hat leider nicht geklappt. Versuch es bitte gleich nochmal.';

  static const _quietLine =
      'Diese Tipps kommen von deiner Berater:in, nicht von Belly Buddy.';

  @override
  ConsumerState<DietitianTipsSection> createState() =>
      _DietitianTipsSectionState();
}

class _DietitianTipsSectionState extends ConsumerState<DietitianTipsSection> {
  bool _showAll = false;

  /// The loaded tips a stamp was scheduled for, so a rebuild of the same
  /// load schedules none again.
  List<DietitianTip>? _stampedLoad;

  /// Whether the last build was visible (its tickers run).
  bool _visible = false;

  void _stampSeen() {
    if (!mounted || !_visible) return;
    unawaited(ref.read(dietitianTipsProvider.notifier).markShownSeen());
  }

  /// Schedules the „seen" stamp for [tips] once, and only while the
  /// section is visible; becoming visible rebuilds it (TickerMode).
  void _scheduleStamp(List<DietitianTip> tips) {
    _visible = TickerMode.valuesOf(context).enabled;
    if (!_visible || identical(tips, _stampedLoad)) return;
    if (!tips.any((t) => t.isNew)) return;
    _stampedLoad = tips;
    WidgetsBinding.instance.addPostFrameCallback((_) => _stampSeen());
  }

  void _tellFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DietitianTipsSection.failedLine)),
    );
  }

  Future<void> _toggleTrying(String id) async {
    try {
      await ref.read(dietitianTipsProvider.notifier).toggleTrying(id);
    } catch (_) {
      // The service logged it (ids only).
      _tellFailed();
    }
  }

  Future<void> _confirmRemove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipp entfernen?'),
        content: const Text(
          'Er verschwindet dann auch aus der Liste deiner Berater:in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dietitianTipsProvider.notifier).remove(id);
    } catch (_) {
      _tellFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(dietitianTipsProvider).value ?? const [];
    if (tips.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(buddyClockProvider)();
    _scheduleStamp(tips);
    final older = tips.skip(1).toList();
    final shownOlder = _showAll ? older : older.take(_olderShown).toList();

    return Column(
      key: DietitianTipsSection.sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscoverSection(
          title: 'Von deiner Berater:in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NewestTip(
                tip: tips.first,
                now: now,
                onTrying: () => unawaited(_toggleTrying(tips.first.id)),
                onRemove: () => unawaited(_confirmRemove(tips.first.id)),
              ),
              if (older.isNotEmpty) ...[
                AppConstants.gap8,
                DiscoverListCard(
                  children: [
                    for (final tip in shownOlder)
                      _OlderTip(
                        tip: tip,
                        onRemove: () => unawaited(_confirmRemove(tip.id)),
                      ),
                  ],
                ),
                if (older.length > _olderShown && !_showAll)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.foreground,
                      ),
                      child: const Text('Alle anzeigen'),
                    ),
                  ),
              ],
              AppConstants.gap8,
              const Text(
                DietitianTipsSection._quietLine,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        AppConstants.gap24,
      ],
    );
  }
}

/// „Entfernen" behind a menu.
class _TipMenu extends StatelessWidget {
  const _TipMenu({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Mehr',
      icon: const Icon(Icons.more_horiz, color: AppTheme.mutedForeground),
      onSelected: (_) => onRemove(),
      itemBuilder: (_) => const [
        PopupMenuItem<bool>(value: true, child: Text('Entfernen')),
      ],
    );
  }
}

class _NewestTip extends StatelessWidget {
  const _NewestTip({
    required this.tip,
    required this.now,
    required this.onTrying,
    required this.onRemove,
  });

  final DietitianTip tip;
  final DateTime now;
  final VoidCallback onTrying;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final trying = tip.tryingAt != null;
    return BbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppConstants.iconBadgeSm,
                height: AppConstants.iconBadgeSm,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  tipInitials(tip.senderName),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.senderName,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBodyLG,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foreground,
                      ),
                    ),
                    Text(
                      '${tip.senderProfession.selfStated} · '
                      '${tipWhen(tip.createdAt, now)}',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (tip.isNew) const DiscoverPill('Neu'),
              _TipMenu(onRemove: onRemove),
            ],
          ),
          AppConstants.gap12,
          Text(
            tip.body,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.foreground,
              height: AppTheme.lineHeightBody,
            ),
          ),
          AppConstants.gap12,
          Align(
            alignment: Alignment.centerLeft,
            child: BbButton(
              label: trying ? 'Probiere ich ✓' : 'Probiere ich',
              isOutlined: !trying,
              onPressed: onTrying,
            ),
          ),
        ],
      ),
    );
  }
}

class _OlderTip extends StatelessWidget {
  const _OlderTip({required this.tip, required this.onRemove});

  final DietitianTip tip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppConstants.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacing12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tip.senderName} · ${_day.format(tip.createdAt.toLocal())}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  AppConstants.gap4,
                  Text(
                    tip.body,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.foreground,
                      height: AppTheme.lineHeightBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _TipMenu(onRemove: onRemove),
        ],
      ),
    );
  }
}
