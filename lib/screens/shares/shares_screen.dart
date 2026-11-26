import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/shares_provider.dart';
import '../../router/route_names.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import 'widgets/share_created_sheet.dart';
import 'widgets/share_tile.dart';

/// Ended, expired and locked shares stay in the list this long.
const _inactiveShownDays = 90;

/// As many active shares as the server allows.
const _maxActiveShares = 5;
const _fullHint =
    'Du hast schon 5 aktive Freigaben. Beende eine, um eine neue zu '
    'erstellen.';

/// „Deine Freigaben": the active shares first, then the ones that ended,
/// expired or were locked in the last 90 days (counted from when they
/// stopped), each group newest first.
class SharesScreen extends ConsumerStatefulWidget {
  const SharesScreen({super.key});

  @override
  ConsumerState<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends ConsumerState<SharesScreen> {
  static const _log = AppLogger('SharesScreen');

  /// A share is being ended (dialog open or call on its way).
  bool _ending = false;

  Future<void> _end(DataShare share) async {
    if (_ending) return;
    _ending = true;
    try {
      final confirmed = await _confirmEnd();
      if (!confirmed || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(sharesProvider.notifier).end(share.id);
      } catch (e, st) {
        _log.error('Ending a share failed', e, st);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Beenden hat nicht geklappt. Versuch es später nochmal.',
            ),
          ),
        );
        // The share may have ended elsewhere already.
        unawaited(ref.read(sharesProvider.notifier).refresh());
      }
    } finally {
      _ending = false;
    }
  }

  Future<bool> _confirmEnd() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Freigabe beenden?'),
        content: const Text(
          'Die Berater:in kann dein Tagebuch dann nicht mehr sehen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// The shares to show with their state, in order.
  List<(DataShare, ShareState)> _visible(List<DataShare> shares) {
    final now = ref.read(buddyClockProvider)();
    final cutoff = addDays(now, -_inactiveShownDays);
    final active = <(DataShare, ShareState)>[];
    final others = <(DataShare, ShareState)>[];
    for (final share in shares) {
      final state = share.stateAt(now);
      if (state == ShareState.active) {
        active.add((share, state));
        continue;
      }
      final stoppedAt = switch (state) {
        ShareState.ended => share.revokedAt,
        ShareState.locked => share.lockedAt,
        _ => share.expiresAt,
      }!;
      if (stoppedAt.isAfter(cutoff)) others.add((share, state));
    }
    int newestFirst((DataShare, ShareState) a, (DataShare, ShareState) b) =>
        b.$1.createdAt.compareTo(a.$1.createdAt);
    return [...active..sort(newestFirst), ...others..sort(newestFirst)];
  }

  /// Opens the sheet of a share created a moment ago, once, on top of the
  /// list.
  void _showJustCreated() {
    final secret = ref.read(justCreatedShareProvider.notifier).take();
    if (secret == null) return;
    unawaited(
      showShareSecretSheet(
        context,
        link: secret.link,
        code: secret.code,
        title: 'Dein Link ist bereit',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Opened, last opened and the state move on without the app.
      unawaited(ref.read(sharesProvider.notifier).refresh());
      _showJustCreated();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(justCreatedShareProvider, (_, secret) {
      if (secret == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showJustCreated();
      });
    });
    final shares = ref.watch(sharesProvider);
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Deine Freigaben'),
      ),
      // hasValue: the list stays while it is refreshed.
      body: shares.hasValue
          ? _content(shares.requireValue)
          : shares.hasError
          ? BbErrorState(
              message: 'Deine Freigaben konnten nicht geladen werden.',
              onRetry: () => ref.invalidate(sharesProvider),
            )
          : const BbLoadingState(),
    );
  }

  Widget _content(List<DataShare> shares) {
    final now = ref.read(buddyClockProvider)();
    final full =
        shares.where((s) => s.stateAt(now) == ShareState.active).length >=
        _maxActiveShares;
    final visible = _visible(shares);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(sharesProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: visible.isEmpty
                  ? const Text(
                      'Teile dein Tagebuch mit deiner Diätolog:in oder '
                      'Ärzt:in. Du entscheidest, was sie sehen, und kannst es '
                      'jederzeit beenden.',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBodyLG,
                        color: AppTheme.foreground,
                        height: AppTheme.lineHeightBody,
                      ),
                    )
                  : _list(visible, full: full),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: BbButton(
                    label: visible.isEmpty
                        ? 'Freigabe erstellen'
                        : 'Weitere Freigabe erstellen',
                    onPressed: full
                        ? null
                        : () => unawaited(context.push(RoutePaths.shareCreate)),
                  ),
                ),
                if (full) ...[
                  AppConstants.gap8,
                  const Text(
                    _fullHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(List<(DataShare, ShareState)> visible, {required bool full}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, (share, state)) in visible.indexed) ...[
            if (i > 0)
              const Divider(
                height: AppConstants.borderWidthSm,
                thickness: AppConstants.borderWidthSm,
                color: AppTheme.border,
              ),
            ShareTile(
              key: ValueKey(share.id),
              share: share,
              state: state,
              onEnd: () => unawaited(_end(share)),
              onShowSecret: (secret) => unawaited(
                showShareSecretSheet(
                  context,
                  link: secret.link,
                  code: secret.code,
                ),
              ),
              onCreateAgain: full
                  ? null
                  : () => unawaited(context.push(RoutePaths.shareCreate)),
            ),
          ],
        ],
      ),
    );
  }
}
