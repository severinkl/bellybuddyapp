import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';

/// The Entdecken tab: the hub over the app's content screens. A bare
/// placeholder until the hub is built.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Entdecken')),
    );
  }
}
