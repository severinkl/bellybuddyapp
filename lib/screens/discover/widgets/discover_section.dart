import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  const DiscoverAllLink({super.key, required this.onTap, this.semanticsLabel});

  final VoidCallback onTap;

  /// What a screen reader says instead of „Alle ›", for a second link in
  /// a section („Alle meine Rezepte").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppTheme.foreground),
      child: Text('Alle ›', semanticsLabel: semanticsLabel),
    );
  }
}

/// A section's quiet card for a line instead of content: nothing there
/// yet, loading, or failed. Never tappable.
class DiscoverNote extends StatelessWidget {
  const DiscoverNote(this.text, {super.key});

  /// For a section whose [value] has no data yet: „Laden…", or once it
  /// failed „[what] konnten nicht geladen werden.".
  DiscoverNote.pending(AsyncValue<Object?> value, String what, {super.key})
    : text = value.hasError ? '$what konnten nicht geladen werden.' : 'Laden…';

  final String text;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBody,
          color: AppTheme.mutedForeground,
          height: AppTheme.lineHeightBody,
        ),
      ),
    );
  }
}

/// A card of rows divided by hairlines (Wissen's articles, the
/// Alternativen); [onTap] makes the whole card one button.
class DiscoverListCard extends StatelessWidget {
  const DiscoverListCard({super.key, this.onTap, required this.children});

  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              const Divider(
                height: AppConstants.dividerThickness,
                thickness: AppConstants.dividerThickness,
                color: AppTheme.border,
              ),
            child,
          ],
        ],
      ),
    );
  }
}
