import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/data_share.dart';
import '../../../services/share_secrets_store.dart';
import '../../../utils/logger.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/bb_labeled_field.dart';

/// The name, period and switches of a share, with the stage 1 rules:
/// photos need meals, patterns need gut, and one of the five data switches
/// must stay on. Notifies on every change, the name's included.
class ShareTermsController extends ChangeNotifier {
  ShareTermsController({
    String name = '',
    SharePeriod period = SharePeriod.days30,
    bool meals = true,
    bool drinks = true,
    bool gut = true,
    bool toilet = true,
    bool patterns = true,
    bool photos = false,
  }) : name = TextEditingController(text: name),
       _period = period,
       _meals = meals,
       _drinks = drinks,
       _gut = gut,
       _toilet = toilet,
       _patterns = patterns && gut,
       _photos = photos && meals {
    this.name.addListener(notifyListeners);
  }

  /// What [share] shares now.
  ShareTermsController.fromShare(DataShare share)
    : this(
        name: share.displayName,
        period: share.period,
        meals: share.shareMeals,
        drinks: share.shareDrinks,
        gut: share.shareGut,
        toilet: share.shareToilet,
        patterns: share.sharePatterns,
        photos: share.sharePhotos,
      );

  final TextEditingController name;
  SharePeriod _period;
  bool _meals;
  bool _drinks;
  bool _gut;
  bool _toilet;
  bool _patterns;
  bool _photos;

  SharePeriod get period => _period;
  bool get meals => _meals;
  bool get drinks => _drinks;
  bool get gut => _gut;
  bool get toilet => _toilet;
  bool get patterns => _patterns;
  bool get photos => _photos;

  String get trimmedName => name.text.trim();

  /// A trimmed name and at least one of the five data switches.
  bool get isValid =>
      trimmedName.isNotEmpty &&
      (_meals || _drinks || _gut || _toilet || _patterns);

  set period(SharePeriod value) => _set(() => _period = value);

  /// Switching meals off takes the photos with it.
  set meals(bool value) => _set(() {
    _meals = value;
    if (!value) _photos = false;
  });

  set drinks(bool value) => _set(() => _drinks = value);

  /// Switching gut off takes the patterns with it.
  set gut(bool value) => _set(() {
    _gut = value;
    if (!value) _patterns = false;
  });

  set toilet(bool value) => _set(() => _toilet = value);

  /// Only while gut is on.
  set patterns(bool value) => _set(() => _patterns = value && _gut);

  /// Only while meals is on.
  set photos(bool value) => _set(() => _photos = value && _meals);

  void _set(void Function() change) {
    change();
    notifyListeners();
  }

  /// The terms of a connection that lasts [duration].
  DietitianShareTerms dietitianTerms(ShareDuration duration) =>
      DietitianShareTerms(
        displayName: trimmedName,
        period: _period,
        duration: duration,
        meals: _meals,
        drinks: _drinks,
        gut: _gut,
        toilet: _toilet,
        patterns: _patterns,
        photos: _photos,
      );

  /// A new link share valid for [validDays].
  NewShare newShare(int validDays) => NewShare(
    displayName: trimmedName,
    period: _period,
    validDays: validDays,
    meals: _meals,
    drinks: _drinks,
    gut: _gut,
    toilet: _toilet,
    patterns: _patterns,
    photos: _photos,
  );

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

/// „Dein Name in der Ansicht", „Zeitraum" and the switches under
/// [switchesHeading]. With [prefillLastName] an empty name takes the one
/// used for the last share.
class ShareTermsForm extends ConsumerStatefulWidget {
  const ShareTermsForm({
    super.key,
    required this.controller,
    required this.switchesHeading,
    this.prefillLastName = false,
  });

  /// The toilet category's one word on the shares screens (the switch
  /// here and the tile's „Sieht …").
  static const toiletLabel = 'Klo-Einträge';

  final ShareTermsController controller;
  final String switchesHeading;
  final bool prefillLastName;

  @override
  ConsumerState<ShareTermsForm> createState() => _ShareTermsFormState();
}

class _ShareTermsFormState extends ConsumerState<ShareTermsForm> {
  static const _log = AppLogger('ShareTermsForm');
  static const _maxNameLength = 40;

  @override
  void initState() {
    super.initState();
    if (widget.prefillLastName) unawaited(_prefillName());
  }

  Future<void> _prefillName() async {
    try {
      final saved = await ref.read(shareSecretsStoreProvider).lastDisplayName();
      final name = widget.controller.name;
      if (!mounted || saved == null || name.text.isNotEmpty) return;
      name.text = saved;
    } catch (e, st) {
      _log.error('reading the last name failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShareFormHeading('Dein Name in der Ansicht'),
          BbLabeledField(
            label: 'Dein Name in der Ansicht',
            child: TextField(
              controller: c.name,
              inputFormatters: const [_CodePointLimit(_maxNameLength)],
              textCapitalization: TextCapitalization.words,
            ),
          ),
          AppConstants.gap16,
          const ShareFormHeading('Zeitraum'),
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
                  selected: c.period == period,
                  onSelected: (_) => c.period = period,
                ),
            ],
          ),
          AppConstants.gap24,
          ShareFormHeading(widget.switchesHeading),
          BbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _switch('Mahlzeiten und Zutaten', c.meals, (v) => c.meals = v),
                _switch('Getränke', c.drinks, (v) => c.drinks = v),
                _switch('Bauchgefühl und Symptome', c.gut, (v) => c.gut = v),
                _switch(
                  ShareTermsForm.toiletLabel,
                  c.toilet,
                  (v) => c.toilet = v,
                ),
                _switch(
                  'Muster und Unverträglichkeiten',
                  c.patterns,
                  c.gut ? (v) => c.patterns = v : null,
                  subtitle: c.gut
                      ? 'Muster zeigen immer die letzten 30 Tage.'
                      : 'Braucht Bauchgefühl',
                ),
                _switch(
                  'Fotos der Mahlzeiten',
                  c.photos,
                  c.meals ? (v) => c.photos = v : null,
                ),
              ],
            ),
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

/// A section heading of the share screens.
class ShareFormHeading extends StatelessWidget {
  const ShareFormHeading(this.text, {super.key});

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

/// Keeps a text at [max] code points, as core counts its `char_length`
/// (Flutter's maxLength counts graphemes: one emoji can be several code
/// points). Cuts whole graphemes only.
class _CodePointLimit extends TextInputFormatter {
  const _CodePointLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    final kept = StringBuffer();
    var count = 0;
    for (final grapheme in newValue.text.characters) {
      count += grapheme.runes.length;
      if (count > max) break;
      kept.write(grapheme);
    }
    final text = kept.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
