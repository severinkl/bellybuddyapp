import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../providers/shares_provider.dart';
import '../../services/share_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_chip_selector.dart';
import 'widgets/share_terms_form.dart';

/// „Mit Berater:in teilen": what a new share shows and for how long. The
/// health consent gate has already sent the user away when the consent is
/// not current.
class ShareCreateScreen extends ConsumerStatefulWidget {
  const ShareCreateScreen({super.key});

  @override
  ConsumerState<ShareCreateScreen> createState() => _ShareCreateScreenState();
}

class _ShareCreateScreenState extends ConsumerState<ShareCreateScreen> {
  static const _log = AppLogger('ShareCreate');
  static const _failed = 'Das hat nicht geklappt. Versuch es später nochmal.';
  static const _validDaysOptions = [7, 30, 90];

  final _terms = ShareTermsController();
  int _validDays = 30;
  bool _submitting = false;

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _terms.isValid;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    // Taken before the await: the screen may be gone when the call returns.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    final justCreated = ref.read(justCreatedShareProvider.notifier);
    final shares = ref.read(sharesProvider.notifier);
    final CreatedShare created;
    try {
      created = await shares.create(_terms.newShare(_validDays));
    } catch (e, st) {
      _log.error('creating a share failed', e, st);
      final message = e is ShareException ? e.message : null;
      messenger.showSnackBar(SnackBar(content: Text(message ?? _failed)));
      if (mounted) setState(() => _submitting = false);
      return;
    }
    // Leave first, then hand over: the list beneath opens the sheet, also
    // when this screen was left while the call was on its way. Still on its
    // way back, this screen is mounted but no longer on top: popping then
    // would close the list.
    if (mounted && (route?.isCurrent ?? false)) router.pop();
    justCreated.set(ShareSecret(link: created.link, code: created.code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Mit Berater:in teilen'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wer deinen Link und Code hat, kann dein Tagebuch '
                    'ansehen, aber nichts ändern.',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBodyLG,
                      color: AppTheme.foreground,
                      height: AppTheme.lineHeightBody,
                    ),
                  ),
                  AppConstants.gap24,
                  ShareTermsForm(
                    controller: _terms,
                    switchesHeading: 'Was wird geteilt?',
                    prefillLastName: true,
                  ),
                  AppConstants.gap24,
                  const ShareFormHeading('Link gültig für'),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    children: [
                      for (final days in _validDaysOptions)
                        BbFilterChip(
                          label: '$days Tage',
                          selected: _validDays == days,
                          onSelected: (_) => setState(() => _validDays = days),
                        ),
                    ],
                  ),
                  AppConstants.gap24,
                  const Text(
                    'Das sind Gesundheitsdaten. Neue Einträge erscheinen '
                    'automatisch. Du kannst die Freigabe jederzeit beenden.',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                      height: AppTheme.lineHeightBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: SizedBox(
                width: double.infinity,
                child: ListenableBuilder(
                  listenable: _terms,
                  builder: (context, _) => BbButton(
                    label: 'Link erstellen',
                    isLoading: _submitting,
                    onPressed: _canSubmit ? () => unawaited(_submit()) : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
