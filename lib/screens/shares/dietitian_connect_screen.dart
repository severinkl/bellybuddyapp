import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../models/dietitian_card.dart';
import '../../providers/shares_provider.dart';
import '../../services/share_service.dart';
import '../../utils/logger.dart';
import '../../utils/practice_code.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import 'plus_required.dart';
import 'widgets/practice_code_scanner.dart';
import 'widgets/share_duration_picker.dart';
import 'widgets/share_terms_form.dart';

/// As many active connections to dietitians as core allows.
const maxActiveDietitians = 3;

/// Shown instead of a way to connect while [maxActiveDietitians] are.
const dietitiansFullHint =
    'Du hast $maxActiveDietitians Berater:innen verbunden. Beende eine Verbindung, um eine neue '
    'hinzuzufügen.';

/// Core's text for an unknown code; also for a text that cannot be one.
const _notFound = 'Diesen Code gibt es nicht. Bitte prüfe ihn.';

/// „Berater:in verbinden": step 1 finds a dietitian by practice code (typed
/// or scanned), step 2 chooses what they see and connects. The health
/// consent gate has already sent the user away when the consent is not
/// current. Neither the code nor the user's text is logged.
class DietitianConnectScreen extends ConsumerStatefulWidget {
  const DietitianConnectScreen({super.key});

  @override
  ConsumerState<DietitianConnectScreen> createState() =>
      _DietitianConnectScreenState();
}

class _DietitianConnectScreenState
    extends ConsumerState<DietitianConnectScreen> {
  static const _log = AppLogger('DietitianConnect');

  final _codeField = TextEditingController();
  final _terms = ShareTermsController();
  ShareDuration _duration = ShareDuration.open;
  String? _lookupError;
  bool _lookingUp = false;
  bool _submitting = false;

  /// The found dietitian and their normalized code: step 2.
  (String, DietitianCard)? _found;

  @override
  void dispose() {
    _codeField.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await ref.read(practiceCodeScanProvider)(context);
    if (code == null || !mounted) return;
    _codeField.text = code;
    await _lookUp();
  }

  Future<void> _lookUp() async {
    if (_lookingUp || _codeField.text.trim().isEmpty) return;
    final code = normalizePracticeCode(_codeField.text);
    if (code == null) {
      setState(() => _lookupError = _notFound);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _lookupError = null;
    });
    try {
      final card = await ref.read(shareServiceProvider).lookup(code);
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _found = (code, card);
      });
    } catch (e, st) {
      _log.error('looking up a practice code failed', e, st);
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _lookupError =
            (e is ShareException ? e.message : null) ?? shareFailedLine;
      });
    }
  }

  Future<void> _connect() async {
    final found = _found;
    if (found == null || _submitting || !_terms.isValid) return;
    final (code, card) = found;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    // Taken before the await: the screen may be gone when the call returns.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    try {
      await ref
          .read(sharesProvider.notifier)
          .connect(code, _terms.dietitianTerms(_duration));
    } catch (e, st) {
      _log.error('connecting a dietitian failed', e, st);
      if (e is ShareException && e.plusRequired) {
        replaceWithPlus(router, mounted ? route : null, messenger, e.message);
        if (mounted) setState(() => _submitting = false);
        return;
      }
      final message = e is ShareException ? e.message : null;
      if (e is ShareException && e.status == 404) {
        // The code went away since the lookup (replaced, or the dietitian
        // blocked): back to step 1, core's text under the field.
        if (mounted) {
          setState(() {
            _submitting = false;
            _found = null;
            _lookupError = message ?? _notFound;
          });
        } else {
          messenger.showSnackBar(SnackBar(content: Text(message ?? _notFound)));
        }
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(message ?? shareFailedLine)),
      );
      if (mounted) setState(() => _submitting = false);
      return;
    }
    // Still on its way back the screen is mounted but not on top: popping
    // then would close the list.
    if (mounted && (route?.isCurrent ?? false)) router.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${card.name} ist verbunden.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return PopScope(
      // Back from step 2 goes to step 1.
      canPop: found == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) setState(() => _found = null);
      },
      child: Scaffold(
        backgroundColor: AppTheme.screenBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.screenBackground,
          title: const Text('Berater:in verbinden'),
        ),
        body: found == null ? _stepOne() : _stepTwo(found.$2),
      ),
    );
  }

  Widget _stepOne() {
    if (ref.watch(activeDietitianCountProvider) >= maxActiveDietitians) {
      return const Padding(
        padding: AppConstants.paddingMd,
        child: Text(
          dietitiansFullHint,
          style: TextStyle(
            fontSize: AppTheme.fontSizeBodyLG,
            color: AppTheme.foreground,
            height: AppTheme.lineHeightBody,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeField,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() => _lookupError = null),
            onSubmitted: (_) => unawaited(_lookUp()),
            decoration: InputDecoration(
              labelText: 'Praxis-Code',
              hintText: 'z. B. BERGER-7K2',
              errorText: _lookupError,
              errorMaxLines: 3,
            ),
          ),
          AppConstants.gap16,
          BbButton(
            label: 'Code suchen',
            isLoading: _lookingUp,
            onPressed: _codeField.text.trim().isEmpty
                ? null
                : () => unawaited(_lookUp()),
          ),
          AppConstants.gap8,
          BbButton(
            label: 'QR-Code scannen',
            isOutlined: true,
            onPressed: _lookingUp ? null : () => unawaited(_scan()),
          ),
        ],
      ),
    );
  }

  Widget _stepTwo(DietitianCard card) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShareFormHeading('Gefunden'),
                SizedBox(
                  width: double.infinity,
                  child: BbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
                        ),
                        AppConstants.gap4,
                        Text(
                          card.line,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeCaptionLG,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppConstants.gap24,
                ShareTermsForm(
                  controller: _terms,
                  switchesHeading: 'Das sieht ${card.name}',
                  prefillLastName: true,
                ),
                AppConstants.gap24,
                ShareDurationPicker(
                  value: _duration,
                  onChanged: (d) => setState(() => _duration = d),
                ),
                AppConstants.gap24,
                const Text(
                  'Du gibst Gesundheitsdaten frei. Du kannst das jederzeit '
                  'unter „Deine Freigaben" beenden.',
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
            padding: AppConstants.paddingMd,
            child: SizedBox(
              width: double.infinity,
              child: ListenableBuilder(
                listenable: _terms,
                builder: (context, _) => BbButton(
                  label: 'Freigeben',
                  isLoading: _submitting,
                  onPressed: _terms.isValid
                      ? () => unawaited(_connect())
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
