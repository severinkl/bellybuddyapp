import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_card.dart';

/// One Entdecken section: its title (with an optional [badge] such as
/// „2 neu") and the header [actions] on the right, [child] below.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    required this.title,
    this.badge,
    this.actions = const [],
    required this.child,
  });

  final String title;
  final String? badge;

  /// Header buttons, e.g. „+" and [DiscoverAllLink].
  final List<Widget> actions;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeTitle,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: AppConstants.spacingSm),
                    DiscoverPill(badge),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
        AppConstants.gap8,
        child,
      ],
    );
  }
}

/// A small green label: „Neu", „2 neu".
class DiscoverPill extends StatelessWidget {
  const DiscoverPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing6,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeSM,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryForeground,
        ),
      ),
    );
  }
}

/// The header's „Alle ›" link to a section's full screen.
class DiscoverAllLink extends StatelessWidget {
  const DiscoverAllLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppTheme.foreground),
      child: const Text('Alle ›'),
    );
  }
}

/// A section's quiet card for a line instead of content: nothing there
/// yet, loading, or failed. Never tappable.
class DiscoverNote extends StatelessWidget {
  const DiscoverNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBody,
          color: AppTheme.mutedForeground,
          height: 1.4,
        ),
      ),
    );
  }
}
