import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/diary_provider.dart';
import 'detail_sheets/meal_detail_sheet.dart';
import 'detail_sheets/toilet_detail_sheet.dart';
import 'detail_sheets/gut_feeling_detail_sheet.dart';
import 'detail_sheets/drink_detail_sheet.dart';

void showDiaryDetailSheet(
  BuildContext context,
  WidgetRef ref,
  DiaryEntry entry,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return switch (entry.data) {
            MealDiaryData() => MealDetailSheet(
              entry: entry,
              data: entry.data as MealDiaryData,
              parentRef: ref,
              scrollController: scrollController,
            ),
            ToiletDiaryData() => ToiletDetailSheet(
              entry: entry,
              data: entry.data as ToiletDiaryData,
              parentRef: ref,
              scrollController: scrollController,
            ),
            GutFeelingDiaryData() => GutFeelingDetailSheet(
              entry: entry,
              data: entry.data as GutFeelingDiaryData,
              parentRef: ref,
              scrollController: scrollController,
            ),
            DrinkDiaryData() => DrinkDetailSheet(
              entry: entry,
              data: entry.data as DrinkDiaryData,
              parentRef: ref,
              scrollController: scrollController,
            ),
          };
        },
      );
    },
  );
}
