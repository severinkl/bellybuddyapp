import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';

/// The Muster page behind Home's insight card (`/patterns`): what the last
/// 30 days of entries show.
///
/// Stage 2 placeholder: only the header so far; the locked and unlocked
/// content follow.
class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key});

  static const title = 'Muster';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(title),
      ),
    );
  }
}
