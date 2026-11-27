import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/data_share.dart';
import '../../../widgets/common/bb_button.dart';
import 'share_tile.dart';

const _deletedName = 'Berater:in (Konto gelöscht)';
const _pausedWord = 'Pausiert';
const _pausedLine = 'Diese Verbindung ist gerade pausiert.';

final _day = DateFormat('d. MMM', 'de_DE');
final _time = DateFormat('HH:mm', 'de_DE');

const _caption = TextStyle(
  fontSize: AppTheme.fontSizeCaptionLG,
  color: AppTheme.mutedForeground,
);

/// A connection whose dietitian deleted their account: core removed the
/// dietitian, nothing can be changed any more.
bool dietitianGone(DataShare share) =>
    share.kind == ShareKind.dietitian &&
    share.dietitianId == null &&
    share.dietitian == null;

/// „Sieht alles außer Fotos", „Sieht alles", or the switched-on names:
/// „Sieht Mahlzeiten und Bauchgefühl".
String dietitianSeesLine(DataShare share) {
  final five = [
    share.shareMeals,
    share.shareDrinks,
    share.shareGut,
    share.shareToilet,
    share.sharePatterns,
  ];
  if (five.every((on) => on)) {
    return share.sharePhotos ? 'Sieht alles' : 'Sieht alles außer Fotos';
  }
  final names = [
    if (share.shareMeals) 'Mahlzeiten',
    if (share.shareDrinks) 'Getränke',
    if (share.shareGut) 'Bauchgefühl',
    if (share.shareToilet) 'Toiletten-Einträge',
    if (share.sharePatterns) 'Muster',
    if (share.sharePhotos) 'Fotos',
  ];
  if (names.isEmpty) return 'Sieht nichts';
  final joined = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} und ${names.last}';
  return 'Sieht $joined';
}

/// „zuletzt angesehen gestern, 16:40" or „noch nicht angesehen". The time is
/// a real instant, shown in local time; [now] is the app's clock.
String dietitianSeenLine(DataShare share, DateTime now) {
  final seen = share.lastOpenedAt?.toLocal();
  if (seen == null) return 'noch nicht angesehen';
  final today = DateTime(now.year, now.month, now.day);
  final seenDay = DateTime(seen.year, seen.month, seen.day);
  final days = today.difference(seenDay).inDays;
  final when = switch (days) {
    0 => 'heute',
    1 => 'gestern',
    _ => _day.format(seen),
  };
  return 'zuletzt angesehen $when, ${_time.format(seen)}';
}

/// One connection to a dietitian: name, card line, state, what they see and
/// the dates; while active „Ändern" and „Beenden", while paused only
/// „Beenden".
class DietitianShareTile extends StatelessWidget {
  const DietitianShareTile({
    super.key,
    required this.share,
    required this.state,
    required this.now,
    required this.onEdit,
    required this.onEnd,
  });

  final DataShare share;
  final ShareState state;
  final DateTime now;

  /// „Ändern".
  final VoidCallback onEdit;

  /// „Beenden".
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final gone = dietitianGone(share);
    final shown = gone ? ShareState.ended : state;
    final active = shown == ShareState.active;
    final paused = active && share.isPaused;
    final card = share.dietitian;
    final end = share.expiresAt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacing14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  card?.name ?? _deletedName,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppTheme.foreground
                        : AppTheme.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                paused ? _pausedWord : shareStateWord(shown),
                style: _caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active && !paused ? AppTheme.shareActive : null,
                ),
              ),
            ],
          ),
          if (card != null) ...[
            AppConstants.gap4,
            Text(card.line, style: _caption),
          ],
          AppConstants.gap6,
          Text(dietitianSeesLine(share), style: _caption),
          AppConstants.gap6,
          Text(
            'seit ${_day.format(share.createdAt.toLocal())}',
            style: _caption,
          ),
          AppConstants.gap4,
          Text(dietitianSeenLine(share, now), style: _caption),
          if (active && end != null) ...[
            AppConstants.gap4,
            Text('bis ${_day.format(end.toLocal())}', style: _caption),
          ],
          if (paused) ...[
            AppConstants.gap6,
            const Text(_pausedLine, style: _caption),
          ],
          if (active) ...[
            AppConstants.gap10,
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: AppConstants.spacingSm,
              children: [
                if (!paused)
                  BbButton(
                    label: 'Ändern',
                    isOutlined: true,
                    onPressed: onEdit,
                  ),
                BbButton(
                  label: 'Beenden',
                  isOutlined: true,
                  isDestructive: true,
                  onPressed: onEnd,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
