import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/navigation_extensions.dart';
import '../../services/plus/plus_copy.dart';
import 'bb_button.dart';
import 'bb_card.dart';

/// What a Plus feature shows while it is locked (spec 4.4): [title], one
/// [line] and „Belly Buddy Plus ansehen", which opens the paywall.
class PlusLockedCard extends StatelessWidget {
  const PlusLockedCard({required this.title, required this.line, super.key});

  /// The button opening `/plus`.
  static const openKey = Key('plus_locked_open');

  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      color: AppTheme.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap6,
          Text(
            line,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              height: AppTheme.lineHeightBody,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          BbButton(
            tapKey: openKey,
            label: PlusCopy.openPlus,
            onPressed: () => context.openPlus(),
          ),
        ],
      ),
    );
  }
}

/// A quiet „Belly Buddy Plus ansehen ›" link to `/plus`, under a note such
/// as [PlusCopy.alternativesNote].
class PlusLink extends StatelessWidget {
  const PlusLink({super.key});

  static const openKey = Key('plus_link_open');

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: openKey,
      onPressed: () => context.openPlus(),
      style: TextButton.styleFrom(foregroundColor: AppTheme.foreground),
      child: const Text('${PlusCopy.openPlus} ›'),
    );
  }
}
