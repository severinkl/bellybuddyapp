import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../router/route_names.dart';
import 'bb_success_overlay.dart';

class TrackerScreenScaffold extends StatelessWidget {
  final Key? trackerKey;
  final String title;
  final Widget? titleWidget;
  final bool showSuccess;
  final String successMessage;
  final String? successSubMessage;
  final String? successMascotAsset;
  final Widget body;
  final Widget? successAction;
  final VoidCallback? onSuccessDismissed;

  const TrackerScreenScaffold({
    super.key,
    this.trackerKey,
    this.title = '',
    this.titleWidget,
    required this.showSuccess,
    required this.successMessage,
    required this.body,
    this.successSubMessage,
    this.successMascotAsset,
    this.successAction,
    this.onSuccessDismissed,
  });

  @override
  Widget build(BuildContext context) {
    if (showSuccess) {
      return BbSuccessOverlay(
        message: successMessage,
        subMessage:
            successSubMessage ?? 'Dein Eintrag wurde erfolgreich erfasst.',
        mascotAsset: successMascotAsset,
        onDismissed:
            onSuccessDismissed ?? () => context.go(RoutePaths.dashboard),
        action: successAction,
      );
    }

    return Scaffold(
      key: trackerKey,
      backgroundColor: AppTheme.screenBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Route through Navigator.maybePop so enclosing PopScope widgets
          // (e.g. the meal tracker's discard-changes guard) can intercept the
          // pop. Falls back to go_router's context.pop when no PopScope blocks.
          onPressed: () async {
            final didPop = await Navigator.maybePop(context);
            if (!didPop && context.mounted) context.pop();
          },
        ),
        title: titleWidget ?? Text(title),
      ),
      body: body,
    );
  }
}
