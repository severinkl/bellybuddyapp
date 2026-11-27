import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/plus_provider.dart';
import '../../providers/shares_provider.dart';
import '../../router/route_names.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import 'dietitian_connect_screen.dart';
import 'widgets/dietitian_share_tile.dart';
import 'widgets/share_created_sheet.dart';
import 'widgets/share_terms_form.dart';
import 'widgets/share_tile.dart';

/// Ended, expired and locked shares stay in the list this long.
const _inactiveShownDays = 90;

/// As many active link shares as the server allows.
const _maxActiveLinks = 5;
const _linksFullHint =
    'Du hast schon $_maxActiveLinks aktive Links. Beende einen, um einen neuen zu '
    'erstellen.';

const _refreshFailed =
    'Aktualisieren hat nicht geklappt. Versuch es später nochmal.';

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
      // Taken before the await: the list may be gone when the call returns.
      final messenger = ScaffoldMessenger.of(context);
      final shares = ref.read(sharesProvider.notifier);
      try {
        await shares.end(share.id);
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
        unawaited(shares.refresh());
      }
    } finally {
      _ending = false;
    }
  }

  /// Loads the list again; a failure keeps it shown and says so. Without a
  /// list the error view says it already.
  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final loaded = await ref.read(sharesProvider.notifier).refresh();
    if (loaded || !mounted || !ref.read(sharesProvider).hasValue) return;
    messenger.showSnackBar(const SnackBar(content: Text(_refreshFailed)));
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
      final stopped = share.stoppedAt;
      if (stopped != null && stopped.isAfter(cutoff)) {
        others.add((share, state));
      }
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
      showShareSecretSheet(context, secret, title: 'Dein Link ist bereit'),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Opened, last opened and the state move on without the app. A list
      // still on its first load (or a reload for a new account) is fresh.
      if (!ref.read(sharesProvider).isLoading) unawaited(_refresh());
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
    // Every active share is visible.
    final visible = _visible(shares);
    final links = [
      for (final v in visible)
        if (v.$1.kind == ShareKind.link) v,
    ];
    final dietitians = [
      for (final v in visible)
        if (v.$1.kind == ShareKind.dietitian) v,
    ];
    final linksFull =
        links.where((v) => v.$2 == ShareState.active).length >= _maxActiveLinks;
    final dietitiansFull =
        ref.watch(activeDietitianCountProvider) >= maxActiveDietitians;
    // New shares need Plus: while it is locked, both buttons and „Neu
    // erstellen" open the paywall; the list, „Ändern" and ending stay.
    final plusLocked = ref.watch(plusAccessProvider) == PlusAccess.locked;
    void openPlus() => unawaited(context.push(RoutePaths.plus));
    final VoidCallback? onCreate = linksFull
        ? null
        : plusLocked
        ? openPlus
        : () => unawaited(context.push(RoutePaths.shareCreate));
    final now = ref.read(buddyClockProvider)();
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dietitians.isNotEmpty)
                          _section(
                            'Verbundene Berater:innen',
                            dietitians,
                            (share, state) => DietitianShareTile(
                              key: ValueKey(share.id),
                              share: share,
                              state: state,
                              now: now,
                              onEdit: () => unawaited(
                                context.push(
                                  RoutePaths.dietitianShareEditFor(share.id),
                                ),
                              ),
                              onEnd: () => unawaited(_end(share)),
                            ),
                          ),
                        if (dietitians.isNotEmpty && links.isNotEmpty)
                          AppConstants.gap20,
                        if (links.isNotEmpty)
                          _section(
                            'Links',
                            links,
                            (share, state) => ShareTile(
                              key: ValueKey(share.id),
                              share: share,
                              state: state,
                              onEnd: () => unawaited(_end(share)),
                              onShowSecret: (secret) => unawaited(
                                showShareSecretSheet(context, secret),
                              ),
                              onCreateAgain: onCreate,
                            ),
                          ),
                      ],
                    ),
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
                    label: 'Berater:in verbinden',
                    onPressed: dietitiansFull
                        ? null
                        : plusLocked
                        ? openPlus
                        : () => unawaited(
                            context.push(RoutePaths.dietitianConnect),
                          ),
                  ),
                ),
                if (dietitiansFull) ...[
                  AppConstants.gap8,
                  const _Hint(dietitiansFullHint),
                ],
                AppConstants.gap8,
                SizedBox(
                  width: double.infinity,
                  child: BbButton(
                    label: 'Link erstellen',
                    isOutlined: true,
                    onPressed: onCreate,
                  ),
                ),
                if (linksFull) ...[
                  AppConstants.gap8,
                  const _Hint(_linksFullHint),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    List<(DataShare, ShareState)> rows,
    Widget Function(DataShare share, ShareState state) tile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShareFormHeading(title),
        BbCard(
          padding: EdgeInsets.zero,
          showBorder: false,
          child: Column(
            children: [
              for (final (i, (share, state)) in rows.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: AppConstants.borderWidthSm,
                    thickness: AppConstants.borderWidthSm,
                    color: AppTheme.border,
                  ),
                tile(share, state),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: AppTheme.fontSizeCaptionLG,
      color: AppTheme.mutedForeground,
    ),
  );
}
