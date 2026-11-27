import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/meal_detail_sheet.dart';
import 'package:belly_buddy/screens/diary/widgets/meal_thumbnail.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';

import '../../../../helpers/fakes.dart';
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

  testWidgets('the meal detail photo reads „Foto: Pasta mit Tomaten"; the '
      'list thumbnail adds no node', (tester) async {
    final semantics = tester.ensureSemantics();
    final meal = MealEntry(
      id: 'meal-1',
      trackedAt: DateTime(2026, 4, 10, 12, 30),
      title: 'Pasta mit Tomaten',
      ingredients: const ['Nudeln'],
      imageUrl: 'https://example.invalid/pasta.jpg',
    );
    final entry = DiaryEntry(
      id: meal.id,
      type: DiaryEntryType.meal,
      trackedAt: meal.trackedAt,
      title: meal.title,
      subtitle: '',
      data: MealDiaryData(meal),
    );
    await tester.pumpWithProviders(
      Scaffold(
        body: Column(
          children: [
            MealThumbnail(imageUrl: meal.imageUrl!),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) => MealDetailSheet(
                  entry: entry,
                  data: entry.data as MealDiaryData,
                  parentRef: ref,
                  scrollController: ScrollController(),
                ),
              ),
            ),
          ],
        ),
      ),
      overrides: [
        mealMediaRepositoryProvider.overrideWithValue(
          FakeMealMediaRepository(),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final images = find.semantics
        .byPredicate((n) => n.flagsCollection.isImage)
        .evaluate();
    expect(images.map((n) => n.label), [
      'Foto: Pasta mit Tomaten',
    ], reason: 'one image node, the detail photo; the thumbnail adds none');
    semantics.dispose();
  });
}
