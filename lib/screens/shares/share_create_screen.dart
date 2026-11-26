import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';

/// Placeholder until the create screen is built.
class ShareCreateScreen extends StatelessWidget {
  const ShareCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Freigabe einrichten'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
