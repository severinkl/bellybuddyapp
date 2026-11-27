import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/diary_provider.dart';
import '../../../widgets/common/bb_sheet_messenger.dart';
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
    // Above the bottom bar and its plus, not under them (the Tagebuch's
    // own navigator lies below the bar); the content keeps clear of the
    // home indicator.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => BbSheetMessenger(
            child: switch (entry.data) {
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
            },
          ),
        ),
      );
    },
  );
}
