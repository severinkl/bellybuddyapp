import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/data_share.dart';
import '../../providers/shares_provider.dart';
import '../../router/route_names.dart';
import '../../services/share_secrets_store.dart';
import '../../services/share_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/bb_chip_selector.dart';

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
  static const _maxNameLength = 40;
  static const _failed = 'Das hat nicht geklappt. Versuch es später nochmal.';
  static const _validDaysOptions = [7, 30, 90];

  final _name = TextEditingController();
  SharePeriod _period = SharePeriod.days30;
  int _validDays = 30;
  bool _meals = true;
  bool _drinks = true;
  bool _gut = true;
  bool _toilet = true;
  bool _patterns = true;
  bool _photos = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prefillName());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _prefillName() async {
    try {
      final saved = await ref.read(shareSecretsStoreProvider).lastDisplayName();
      if (!mounted || saved == null || _name.text.isNotEmpty) return;
      setState(() => _name.text = saved);
    } catch (e, st) {
      _log.error('reading the last name failed', e, st);
    }
  }

  bool get _canSubmit =>
      !_submitting &&
      _name.text.trim().isNotEmpty &&
      (_meals || _drinks || _gut || _toilet || _patterns);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final CreatedShare created;
    try {
      created = await ref
          .read(sharesProvider.notifier)
          .create(
            NewShare(
              displayName: _name.text.trim(),
              period: _period,
              validDays: _validDays,
              meals: _meals,
              drinks: _drinks,
              gut: _gut,
              toilet: _toilet,
              patterns: _patterns,
              photos: _photos,
            ),
          );
    } catch (e, st) {
      _log.error('creating a share failed', e, st);
      final message = e is ShareException ? e.message : null;
      messenger.showSnackBar(SnackBar(content: Text(message ?? _failed)));
      if (mounted) setState(() => _submitting = false);
      return;
    }
    ref
        .read(justCreatedShareProvider.notifier)
        .set(ShareSecret(link: created.link, code: created.code));
    unawaited(router.pushReplacement(RoutePaths.shares));
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
                  const _Heading('Dein Name in der Ansicht'),
                  TextField(
                    controller: _name,
                    maxLength: _maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  AppConstants.gap16,
                  const _Heading('Zeitraum'),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    children: [
                      for (final (period, label) in [
                        (SharePeriod.days14, '14 Tage'),
                        (SharePeriod.days30, '30 Tage'),
                        (SharePeriod.all, 'Alles'),
                      ])
                        BbFilterChip(
                          label: label,
                          selected: _period == period,
                          onSelected: (_) => setState(() => _period = period),
                        ),
                    ],
                  ),
                  AppConstants.gap24,
                  const _Heading('Was wird geteilt?'),
                  _switches(),
                  AppConstants.gap24,
                  const _Heading('Link gültig für'),
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
                child: BbButton(
                  label: 'Link erstellen',
                  isLoading: _submitting,
                  onPressed: _canSubmit ? () => unawaited(_submit()) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switches() {
    return BbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _switch(
            'Mahlzeiten und Zutaten',
            _meals,
            (v) => setState(() {
              _meals = v;
              if (!v) _photos = false;
            }),
          ),
          _switch('Getränke', _drinks, (v) => setState(() => _drinks = v)),
          _switch(
            'Bauchgefühl und Symptome',
            _gut,
            (v) => setState(() {
              _gut = v;
              if (!v) _patterns = false;
            }),
          ),
          _switch('Stuhlgang', _toilet, (v) => setState(() => _toilet = v)),
          _switch(
            'Muster und Unverträglichkeiten',
            _patterns,
            _gut ? (v) => setState(() => _patterns = v) : null,
            subtitle: _gut
                ? 'Muster zeigen immer die letzten 30 Tage.'
                : 'Braucht Bauchgefühl',
          ),
          _switch(
            'Fotos der Mahlzeiten',
            _photos,
            _meals ? (v) => setState(() => _photos = v) : null,
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String label,
    bool value,
    ValueChanged<bool>? onChanged, {
    String? subtitle,
  }) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBodyLG,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
  }
}
