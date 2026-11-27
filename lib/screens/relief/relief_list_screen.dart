import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/relief_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/relief/relief_content.dart';
import '../../services/relief/relief_rules.dart';
import '../../widgets/buddy/buddy_pose.dart';
import '../../widgets/buddy/buddy_says.dart';
import 'widgets/relief_safety.dart';

/// "Ruhe für den Bauch" (`/relief`): the Buddy's welcome and one card per
/// exercise, liked ones first. The safety line stays fixed below the list.
class ReliefListScreen extends ConsumerWidget {
  const ReliefListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(orderedReliefExercisesProvider);
    final answers = ref.watch(reliefFeedbackProvider).value ?? const {};
    final markers = ref.watch(reliefReviewMarkersProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(ReliefCopy.title),
        leading: BackButton(
          onPressed: () => context.popOr(RoutePaths.discover),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppConstants.paddingMd,
                children: [
                  const BuddySays(
                    mood: BuddyMood.zen,
                    line: ReliefCopy.listIntro,
                    height: AppConstants.reliefListBuddyHeight,
                  ),
                  AppConstants.gap16,
                  for (final exercise in exercises) ...[
                    _ExerciseCard(
                      exercise: exercise,
                      helped: answers[exercise.id] == ReliefAnswer.yes,
                      showDraft: markers && !exercise.reviewed,
                    ),
                    AppConstants.gap12,
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
              child: ReliefSafetyLine(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.helped,
    required this.showDraft,
  });

  final ReliefExercise exercise;
  final bool helped;
  final bool showDraft;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: () => context.push(RoutePaths.reliefExerciseFor(exercise.id)),
        child: Padding(
          padding: AppConstants.paddingMd,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeSubtitle,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                    AppConstants.gap4,
                    Text(
                      exercise.subtitle,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    AppConstants.gap8,
                    Text(
                      ReliefCopy.minutesLabel(exercise.minutes),
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    if (helped)
                      const Text(
                        ReliefCopy.helpedLabel,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeCaption,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    if (showDraft)
                      const Text(
                        ReliefCopy.draftMarker,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeCaption,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
