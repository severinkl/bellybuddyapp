import 'package:material_ui/material_ui.dart';
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
          builder: (context, scrollController) => _SheetMessenger(
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

/// The sheet's own messenger, so its SnackBars (a failed delete or save)
/// show in the sheet. The app's messenger paints on the shell's Scaffold,
/// which lies under this root-navigator sheet and its scrim.
class _SheetMessenger extends StatelessWidget {
  final Widget child;

  const _SheetMessenger({required this.child});

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The sheet keeps its height with the keyboard up, as before.
        resizeToAvoidBottomInset: false,
        body: child,
      ),
    );
  }
}
