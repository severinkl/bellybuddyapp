import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';
import '../../router/route_names.dart';
import '../../services/journey/journey_copy.dart';
import '../../widgets/buddy/buddy_actions.dart';
import '../../widgets/buddy/buddy_controller.dart';
import '../../widgets/buddy/buddy_pose.dart';
import '../../widgets/buddy/buddy_stage.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_success_overlay.dart';

/// „Muster frei!": the full-screen celebration of day 7, pushed by the Buddy
/// when the patterns unlock. The button replaces it with the Muster page; a
/// tap elsewhere goes back.
class PatternsUnlockedScreen extends StatefulWidget {
  const PatternsUnlockedScreen({super.key});

  static const openKey = Key('patterns_unlocked_open');
  static const title = 'Muster frei!';
  static const line =
      '7 Tage und 3× Bauchgefühl: Ich hab mir deine Einträge angeschaut. '
      'Deine Muster-Seite ist jetzt frei.';

  @override
  State<PatternsUnlockedScreen> createState() => _PatternsUnlockedScreenState();
}

class _PatternsUnlockedScreenState extends State<PatternsUnlockedScreen> {
  final _buddy = BuddyController(mood: BuddyMood.inLove);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: a still Buddy.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _buddy.play(BuddyAction.celebrate);
    }
  }

  @override
  void dispose() {
    _buddy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BbSuccessOverlay(
        message: PatternsUnlockedScreen.title,
        subMessage: PatternsUnlockedScreen.line,
        illustration: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AppConstants.patternsUnlockedBuddyHeight,
          ),
          child: BuddyStage(controller: _buddy, bubbleHeight: 0),
        ),
        actions: [
          BbButton(
            tapKey: PatternsUnlockedScreen.openKey,
            label: JourneyCopy.toPatterns,
            onPressed: () => context.pushReplacement(RoutePaths.patterns),
          ),
        ],
        onDismissed: () => context.pop(),
      ),
    );
  }
}
