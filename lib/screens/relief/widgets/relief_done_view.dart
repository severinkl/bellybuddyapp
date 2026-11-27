import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/relief_provider.dart';
import '../../../services/relief/relief_content.dart';
import '../../../services/relief/relief_rules.dart';
import '../../../widgets/buddy/buddy_pose.dart';
import '../../../widgets/buddy/buddy_says.dart';
import 'relief_safety.dart';

/// The end of an exercise: the Buddy, „Hat's geholfen?" with three answers
/// and „Fertig". An answer is stored and replaced by a thank-you line;
/// „Nein" also links to the safety sheet. Leaving without an answer stores
/// nothing.
class ReliefDoneView extends ConsumerStatefulWidget {
  const ReliefDoneView({
    super.key,
    required this.exerciseId,
    required this.onFinish,
  });

  final String exerciseId;
  final VoidCallback onFinish;

  @override
  ConsumerState<ReliefDoneView> createState() => _ReliefDoneViewState();
}

class _ReliefDoneViewState extends ConsumerState<ReliefDoneView> {
  ReliefAnswer? _answer;

  void _answerWith(ReliefAnswer answer) {
    setState(() => _answer = answer);
    unawaited(
      ref
          .read(reliefFeedbackProvider.notifier)
          .record(widget.exerciseId, answer),
    );
  }

  @override
  Widget build(BuildContext context) {
    const question = TextStyle(
      fontSize: AppTheme.fontSizeTitle,
      fontWeight: FontWeight.w600,
      color: AppTheme.foreground,
    );
    const thanks = TextStyle(
      fontSize: AppTheme.fontSizeBodyLG,
      color: AppTheme.foreground,
    );
    final answer = _answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BuddySays(
                  mood: BuddyMood.zen,
                  line: ReliefCopy.doneLine,
                  height: AppConstants.reliefBuddyHeight,
                ),
                AppConstants.gap24,
                if (answer == null) ...[
                  const Text(
                    ReliefCopy.helpedQuestion,
                    style: question,
                    textAlign: TextAlign.center,
                  ),
                  AppConstants.gap12,
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppConstants.spacingSm,
                    runSpacing: AppConstants.spacingSm,
                    children: [
                      for (final (a, label) in const [
                        (ReliefAnswer.yes, ReliefCopy.answerYes),
                        (ReliefAnswer.little, ReliefCopy.answerLittle),
                        (ReliefAnswer.no, ReliefCopy.answerNo),
                      ])
                        OutlinedButton(
                          onPressed: () => _answerWith(a),
                          style: OutlinedButton.styleFrom(
                            minimumSize: AppConstants.minTapSize,
                          ),
                          child: Text(label),
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    answer == ReliefAnswer.no
                        ? ReliefCopy.thanksNo
                        : ReliefCopy.thanks,
                    style: thanks,
                    textAlign: TextAlign.center,
                  ),
                  if (answer == ReliefAnswer.no) ...[
                    AppConstants.gap8,
                    Center(
                      child: TextButton(
                        onPressed: () => showReliefSafetySheet(context),
                        child: const Text(ReliefCopy.safetySheetTitle),
                      ),
                    ),
                  ],
                ],
                AppConstants.gap16,
                Center(
                  child: TextButton(
                    onPressed: widget.onFinish,
                    style: TextButton.styleFrom(
                      minimumSize: AppConstants.minTapSize,
                    ),
                    child: const Text(ReliefCopy.done),
                  ),
                ),
              ],
            ),
          ),
        ),
        const ReliefSafetyLine(),
      ],
    );
  }
}
