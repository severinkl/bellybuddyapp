import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../config/constants.dart';
import '../providers/buddy_onboarding_gate_provider.dart';

/// `/loading`: where the dashboard and the diary wait after sign-in or an
/// app start until the Buddy onboarding gate knows where the user goes
/// ([buddyOnboardingGatePendingProvider]). Stops waiting after
/// [AppConstants.buddyGateMaxWait], so a hanging backend never blocks the
/// app.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  late final Timer _giveUp;

  @override
  void initState() {
    super.initState();
    _giveUp = Timer(
      AppConstants.buddyGateMaxWait,
      () => ref.read(buddyOnboardingGatePendingProvider.notifier).release(),
    );
  }

  @override
  void dispose() {
    _giveUp.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
