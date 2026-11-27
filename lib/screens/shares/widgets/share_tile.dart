import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/data_share.dart';
import '../../../providers/shares_provider.dart';
import '../../../widgets/common/bb_button.dart';

/// The German word for a share's state.
String shareStateWord(ShareState state) => switch (state) {
  ShareState.active => 'Aktiv',
  ShareState.ended => 'Beendet',
  ShareState.expired => 'Abgelaufen',
  ShareState.locked => 'Gesperrt',
};

final _day = DateFormat('d. MMM', 'de_DE');
final _time = DateFormat('HH:mm', 'de_DE');

const _caption = TextStyle(
  fontSize: AppTheme.fontSizeCaptionLG,
  color: AppTheme.mutedForeground,
);

/// „Erstellt am 12. Nov. · noch nicht geöffnet", or with „zuletzt geöffnet
/// 25. Nov., 16:40" and, from the second opening, „ · 3-mal geöffnet". The
/// times are real instants, shown in local time.
String shareInfoLine(DataShare share) {
  final created = 'Erstellt am ${_day.format(share.createdAt.toLocal())}';
  final opened = share.lastOpenedAt?.toLocal();
  if (share.openCount == 0 || opened == null) {
    return '$created · noch nicht geöffnet';
  }
  final last =
      'zuletzt geöffnet ${_day.format(opened)}, ${_time.format(opened)}';
  final count = share.openCount > 1 ? ' · ${share.openCount}-mal geöffnet' : '';
  return '$created · $last$count';
}

/// One share of the list: its description, state, dates and, while it is
/// active, what can be done with it.
class ShareTile extends ConsumerWidget {
  const ShareTile({
    super.key,
    required this.share,
    required this.state,
    required this.onEnd,
    required this.onShowSecret,
    required this.onCreateAgain,
  });

  final DataShare share;
  final ShareState state;

  /// „Freigabe beenden".
  final VoidCallback onEnd;

  /// „Link und Code anzeigen", with the secret kept on this device.
  final void Function(ShareSecret secret) onShowSecret;

  /// „Neu erstellen", without a secret on this device; null while the limit
  /// of active shares is reached.
  final VoidCallback? onCreateAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = state == ShareState.active;
    // Only an active share offers its secret. One that cannot be read
    // counts as not stored: ending must stay possible.
    final stored = active ? ref.watch(shareSecretProvider(share.id)) : null;
    final secretLoaded = stored != null && (stored.hasValue || stored.hasError);
    final secret = stored?.value;
    final expiresAt = share.expiresAt;
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
                  share.description,
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
                shareStateWord(state),
                style: _caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.shareActive : null,
                ),
              ),
            ],
          ),
          AppConstants.gap6,
          Text(shareInfoLine(share), style: _caption),
          if (share.keeper != null) ...[
            AppConstants.gap6,
            Text('Behalten von ${share.keeper!.name}', style: _caption),
          ],
          if (active && expiresAt != null) ...[
            AppConstants.gap6,
            Text(
              'gültig bis ${_day.format(expiresAt.toLocal())}',
              style: _caption,
            ),
          ],
          if (secretLoaded) ...[
            if (secret == null) ...[
              AppConstants.gap6,
              const Text('Auf diesem Gerät nicht gespeichert', style: _caption),
            ],
            AppConstants.gap10,
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: AppConstants.spacingSm,
              children: [
                if (secret != null)
                  BbButton(
                    label: 'Link und Code anzeigen',
                    isOutlined: true,
                    onPressed: () => onShowSecret(secret),
                  )
                else
                  BbButton(
                    label: 'Neu erstellen',
                    isOutlined: true,
                    onPressed: onCreateAgain,
                  ),
                BbButton(
                  label: 'Freigabe beenden',
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
