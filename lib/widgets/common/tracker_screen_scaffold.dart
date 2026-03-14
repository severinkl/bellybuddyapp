import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../router/route_names.dart';
import 'bb_success_overlay.dart';

class TrackerScreenScaffold extends StatelessWidget {
  final String title;
  final bool showSuccess;
  final String successMessage;
  final Widget body;
  final Widget? successAction;
  final VoidCallback? onSuccessDismissed;

  const TrackerScreenScaffold({
    super.key,
    required this.title,
    required this.showSuccess,
    required this.successMessage,
    required this.body,
    this.successAction,
    this.onSuccessDismissed,
  });

  @override
  Widget build(BuildContext context) {
    if (showSuccess) {
      return BbSuccessOverlay(
        message: successMessage,
        onDismissed: onSuccessDismissed ?? () => context.go(RoutePaths.dashboard),
        action: successAction,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: body,
    );
  }
}
