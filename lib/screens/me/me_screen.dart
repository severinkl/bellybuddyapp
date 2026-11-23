import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';

/// The Ich tab: the Buddy, the streak, settings, the tutorial and
/// feedback. A bare placeholder until the tab is built.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Ich')),
    );
  }
}
