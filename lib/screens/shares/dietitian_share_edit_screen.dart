import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/shares_provider.dart';
import '../../services/share_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import 'widgets/share_duration_picker.dart';
import 'widgets/share_terms_form.dart';

const _failed = 'Das hat nicht geklappt. Versuch es später nochmal.';

/// „Freigabe ändern": what the connection [id] shares and for how long.
class DietitianShareEditScreen extends ConsumerStatefulWidget {
  const DietitianShareEditScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DietitianShareEditScreen> createState() =>
      _DietitianShareEditScreenState();
}

class _DietitianShareEditScreenState
    extends ConsumerState<DietitianShareEditScreen> {
  static const _log = AppLogger('DietitianShareEdit');

  /// Filled from the share once it is there; then the user's.
  ShareTermsController? _terms;
  ShareDuration _duration = ShareDuration.open;
  bool _submitting = false;

  @override
  void dispose() {
    _terms?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final terms = _terms;
    if (terms == null || _submitting || !terms.isValid) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    try {
      await ref
          .read(sharesProvider.notifier)
          .updateTerms(widget.id, terms.dietitianTerms(_duration));
    } catch (e, st) {
      _log.error('updating a connection failed', e, st);
      final message = e is ShareException ? e.message : null;
      messenger.showSnackBar(SnackBar(content: Text(message ?? _failed)));
      if (mounted) setState(() => _submitting = false);
      return;
    }
    if (mounted && (route?.isCurrent ?? false)) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final shares = ref.watch(sharesProvider);
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Freigabe ändern'),
      ),
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
    DataShare? share;
    for (final s in shares) {
      if (s.id == widget.id && s.kind == ShareKind.dietitian) share = s;
    }
    // A form already open stays while the list reloads under it.
    if (_terms == null &&
        (share == null || share.stateAt(now) != ShareState.active)) {
      return const Padding(
        padding: AppConstants.paddingMd,
        child: Text(
          'Diese Verbindung ist beendet.',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBodyLG,
            color: AppTheme.foreground,
          ),
        ),
      );
    }
    final terms = _terms ??= _start(share!);
    final name = share?.dietitian?.name ?? 'deine Berater:in';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShareTermsForm(
                  controller: terms,
                  switchesHeading: 'Das sieht $name',
                ),
                AppConstants.gap24,
                ShareDurationPicker(
                  value: _duration,
                  onChanged: (d) => setState(() => _duration = d),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: AppConstants.paddingMd,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ListenableBuilder(
                    listenable: terms,
                    builder: (context, _) => BbButton(
                      label: 'Speichern',
                      isLoading: _submitting,
                      onPressed: terms.isValid
                          ? () => unawaited(_save())
                          : null,
                    ),
                  ),
                ),
                AppConstants.gap8,
                const Text(
                  'Mehr freigeben gilt ab jetzt. Weniger freigeben gilt '
                  'sofort.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ShareTermsController _start(DataShare share) {
    _duration = share.expiresAt == null
        ? ShareDuration.open
        : ShareDuration.days90;
    return ShareTermsController.fromShare(share);
  }
}
