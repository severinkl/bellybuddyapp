import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/meal_detail_sheet.dart';

import '../../../../helpers/riverpod_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  testWidgets('renders a Bearbeiten button that navigates to the edit route', (
    tester,
  ) async {
    final meal = MealEntry(
      id: 'meal-42',
      trackedAt: DateTime(2026, 4, 10, 12, 30),
      title: 'Pasta',
      ingredients: const ['Nudeln'],
    );
    final entry = DiaryEntry(
      id: meal.id,
      type: DiaryEntryType.meal,
      trackedAt: meal.trackedAt,
      title: meal.title,
      subtitle: '',
      data: MealDiaryData(meal),
    );

    String? pushedPath;
    Object? pushedExtra;
    final router = GoRouter(
      initialLocation: '/diary',
      routes: [
        GoRoute(
          path: '/diary',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => MealDetailSheet(
                entry: entry,
                data: entry.data as MealDiaryData,
                parentRef: ref,
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/meal-tracker/:id',
          builder: (context, state) {
            pushedPath = state.uri.toString();
            pushedExtra = state.extra;
            return const Scaffold(body: Text('edit target'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: createContainer(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();

    expect(pushedPath, '/meal-tracker/meal-42');
    expect(
      pushedExtra,
      same(meal),
      reason:
          'extra must carry the MealEntry so the tracker screen can seed '
          "without an entriesProvider lookup (which the diary's "
          'diaryEntriesProvider path never populates).',
    );
  });
}
