// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';

/// Creates a [ProviderContainer] with the given overrides.
/// Automatically disposes after the test via [ProviderContainer.test].
/// MUST be called inside a `test()` or `setUp()` block.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(overrides: overrides);
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
