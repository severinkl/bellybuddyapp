// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/entries_provider.dart';

/// Creates a [ProviderContainer] with the given overrides.
/// Automatically disposes after the test via [ProviderContainer.test].
/// MUST be called inside a `test()` or `setUp()` block.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(overrides: overrides);
}

/// An [EntriesNotifier] whose [build] returns a pre-seeded [EntriesState] so
/// widgets that `ref.read(entriesProvider)` in `initState` see the supplied
/// meals without needing to wait for [EntriesNotifier.loadEntries].
class _SeededEntriesNotifier extends EntriesNotifier {
  _SeededEntriesNotifier(this._meals);
  final List<MealEntry> _meals;

  @override
  EntriesState build() => EntriesState(meals: _meals);
}

/// Returns an [Override] for [entriesProvider] that serves the supplied list
/// of meals (and empty lists for the other entry types). Use this in widget
/// tests that render the meal edit flow, since the screen reads meals from
/// [entriesProvider] in `initState` to seed the tracker.
Override entriesProviderSeededWith(List<MealEntry> meals) {
  return entriesProvider.overrideWith(() => _SeededEntriesNotifier(meals));
}

/// Extension on [WidgetTester] to pump a widget with ProviderScope,
/// MaterialApp, AppTheme, and German locale — matching the real app setup.
extension PumpWithProviders on WidgetTester {
  Future<void> pumpWithProviders(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.theme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de', 'DE')],
          locale: const Locale('de', 'DE'),
          home: widget,
        ),
      ),
    );
  }
}
