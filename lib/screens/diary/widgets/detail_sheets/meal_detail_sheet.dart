import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/constants.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import '../../../../router/route_names.dart';
import 'detail_sheet_scaffold.dart';
import 'meal_detail.dart';

class MealDetailSheet extends StatelessWidget {
  final DiaryEntry entry;
  final MealDiaryData data;
  final WidgetRef parentRef;
  final ScrollController scrollController;

  const MealDetailSheet({
    super.key,
    required this.entry,
    required this.data,
    required this.parentRef,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return DetailSheetScaffold(
      title: entry.title,
      trackedAt: entry.trackedAt,
      scrollController: scrollController,
      canEdit: false,
      isEditing: false,
      saving: false,
      onDeletePressed: () async {
        Navigator.pop(context);
        await parentRef
            .read(entriesProvider.notifier)
            .deleteByType(entry.type.name, entry.id);
        final date = parentRef.read(diaryDateProvider);
        parentRef.invalidate(diaryEntriesProvider(date));
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MealDetail(meal: data.meal),
          AppConstants.gap16,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Bearbeiten'),
              onPressed: () =>
                  context.push(RoutePaths.mealTrackerEditFor(data.meal.id)),
            ),
          ),
        ],
      ),
    );
  }
}
