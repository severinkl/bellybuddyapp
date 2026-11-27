import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/feedback.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/feedback_context_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/me/feedback_screen.dart';
import 'package:belly_buddy/services/feedback_service.dart';

import '../../helpers/app_host.dart';
import '../../helpers/mocks.dart';

const _ctx = FeedbackContext(
  appVersion: '1.3.0',
  platform: 'ios',
  osVersion: '18.1',
);

const _tooMany =
    "Du hast heute schon 5-mal Feedback geschickt. Morgen geht's wieder.";
const _generic = 'Das hat nicht geklappt. Versuch es später nochmal.';
const _thanks = 'Danke! Dein Feedback ist angekommen.';

/// One call of [FeedbackService.send].
typedef _Sent = ({
  FeedbackCategory category,
  String message,
  bool replyWanted,
  FeedbackContext context,
});

class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService() : super(MockSupabaseClient());

  final sent = <_Sent>[];

  /// Answers every call; by default success.
  Future<void> Function() answer = () async {};

  @override
  Future<void> send({
    required FeedbackCategory category,
    required String message,
    required bool replyWanted,
    required FeedbackContext context,
  }) {
    sent.add((
      category: category,
      message: message,
      replyWanted: replyWanted,
      context: context,
    ));
    return answer();
  }
}

User _user(String? email) => User.fromJson({
  'id': 'u1',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'aud': 'authenticated',
  'created_at': '2026-11-01T00:00:00Z',
  'email': ?email,
})!;

void main() {
  late _FakeFeedbackService service;
  late GoRouter router;

  setUp(() => service = _FakeFeedbackService());

  /// The host page `page:/me` with the form pushed on top of it.
  Future<void> pump(
    WidgetTester tester, {
    String? email = 'mia@example.com',
  }) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: [
        feedbackServiceProvider.overrideWithValue(service),
        feedbackContextProvider.overrideWith((_) async => _ctx),
        currentUserProvider.overrideWithValue(_user(email)),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.me,
      routes: [
        ...stubRoutes([RoutePaths.me]),
        GoRoute(
          path: RoutePaths.feedback,
          builder: (_, _) => const FeedbackScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(RoutePaths.feedback));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
  }

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(FeedbackScreen.sendKey)).enabled;

  Future<void> choose(WidgetTester tester, FeedbackCategory c) async {
    await tester.tap(find.byKey(FeedbackScreen.categoryKey(c)));
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(FeedbackScreen.messageKey), text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(FeedbackScreen.sendKey));
    await tester.tap(find.byKey(FeedbackScreen.sendKey));
    await tester.pump();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(FeedbackScreen.messageKey))
      .controller!
      .text;

  testWidgets('shows the form copy', (tester) async {
    await pump(tester);
    expect(find.text('Feedback geben'), findsOneWidget);
    expect(find.text('Worum geht es?'), findsOneWidget);
    for (final c in FeedbackCategory.values) {
      expect(find.text(c.label), findsOneWidget);
    }
    expect(find.text('Deine Nachricht'), findsOneWidget);
    expect(
      find.text('Was ist dir aufgefallen, was wünschst du dir?'),
      findsOneWidget,
    );
    expect(find.text('Senden'), findsOneWidget);
    expect(find.text('0 / 2000'), findsOneWidget);
  });

  testWidgets('the message field is announced once', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('Deine Nachricht')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Senden is disabled until a category and non-blank text', (
    tester,
  ) async {
    await pump(tester);
    expect(sendEnabled(tester), isFalse);

    await choose(tester, FeedbackCategory.idea);
    expect(sendEnabled(tester), isFalse);

    await type(tester, '   ');
    expect(sendEnabled(tester), isFalse);

    await type(tester, 'Idee!');
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('text without a category keeps Senden disabled', (tester) async {
    await pump(tester);
    await type(tester, 'Idee!');
    expect(sendEnabled(tester), isFalse);
  });

  testWidgets('shows the context lines', (tester) async {
    await pump(tester);
    expect(find.text('Das wird mitgeschickt:'), findsOneWidget);
    expect(find.text('App-Version 1.3.0'), findsOneWidget);
    expect(find.text('System: iOS 18.1'), findsOneWidget);
    expect(find.text('Keine Tagebuch- oder Gesundheitsdaten.'), findsOneWidget);
    expect(
      find.text(
        'Bitte schreib hier keine Gesundheitsdaten hinein, die du nicht '
        'teilen möchtest.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('context lines show … while loading', (tester) async {
    final never = Completer<FeedbackContext>();
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: [
        feedbackServiceProvider.overrideWithValue(service),
        feedbackContextProvider.overrideWith((_) => never.future),
        currentUserProvider.overrideWithValue(_user(null)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FeedbackScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('App-Version …'), findsOneWidget);
    expect(find.text('System: …'), findsOneWidget);
  });

  testWidgets('reply switch shows the account address', (tester) async {
    await pump(tester);
    expect(find.byKey(FeedbackScreen.replyKey), findsOneWidget);
    expect(find.text('Antwort erwünscht'), findsOneWidget);
    expect(find.text('Wir antworten an mia@example.com.'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(FeedbackScreen.replyKey)).value,
      isFalse,
    );
  });

  testWidgets('reply switch is hidden without an address', (tester) async {
    await pump(tester, email: null);
    expect(find.byKey(FeedbackScreen.replyKey), findsNothing);
    expect(find.text('Antwort erwünscht'), findsNothing);
  });

  testWidgets('feedbackMaxLength counts characters a person sees', (
    tester,
  ) async {
    await pump(tester);
    const family = '👨‍👩‍👧';
    await type(tester, family * (AppConstants.feedbackMaxLength + 1));
    expect(fieldText(tester).characters.length, AppConstants.feedbackMaxLength);
    expect(fieldText(tester), family * AppConstants.feedbackMaxLength);
    expect(find.text('2000 / 2000'), findsOneWidget);
  });

  testWidgets('sends trimmed text with category, reply flag and context, '
      'then pops with the thanks SnackBar', (tester) async {
    await pump(tester);
    await choose(tester, FeedbackCategory.problem);
    await type(tester, '  Der Knopf klemmt.\n ');
    await tester.tap(find.byKey(FeedbackScreen.replyKey));
    await tester.pump();

    await tapSend(tester);
    await tester.pumpAndSettle();

    expect(service.sent, hasLength(1));
    final sent = service.sent.single;
    expect(sent.category, FeedbackCategory.problem);
    expect(sent.message, 'Der Knopf klemmt.');
    expect(sent.replyWanted, isTrue);
    expect(sent.context, same(_ctx));
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.text('page:${RoutePaths.me}'), findsOneWidget);
    expect(find.text(_thanks), findsOneWidget);
  });

  testWidgets('reply flag stays off unless switched on', (tester) async {
    await pump(tester);
    await choose(tester, FeedbackCategory.praise);
    await type(tester, 'Toll!');
    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(service.sent.single.replyWanted, isFalse);
  });

  testWidgets('keeps the text and shows the server message on 429', (
    tester,
  ) async {
    service.answer = () async =>
        throw const FeedbackException(status: 429, message: _tooMany);
    await pump(tester);
    await choose(tester, FeedbackCategory.idea);
    await type(tester, 'Noch eine Idee');

    await tapSend(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text(_tooMany), findsOneWidget);
    expect(fieldText(tester), 'Noch eine Idee');
    expect(find.text(_thanks), findsNothing);
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('shows another 4xx message from the server', (tester) async {
    const noEmail = 'Für eine Antwort braucht dein Konto eine E-Mail-Adresse.';
    service.answer = () async =>
        throw const FeedbackException(status: 400, message: noEmail);
    await pump(tester);
    await choose(tester, FeedbackCategory.idea);
    await type(tester, 'Idee');
    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(find.text(noEmail), findsOneWidget);
  });

  testWidgets('a 5xx with a message shows the generic one', (tester) async {
    service.answer = () async =>
        throw const FeedbackException(status: 500, message: 'Interner Fehler');
    await pump(tester);
    await choose(tester, FeedbackCategory.idea);
    await type(tester, 'Idee');
    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(find.text(_generic), findsOneWidget);
    expect(find.text('Interner Fehler'), findsNothing);
  });

  testWidgets('shows the generic message when offline', (tester) async {
    service.answer = () async => throw const FeedbackException();
    await pump(tester);
    await choose(tester, FeedbackCategory.other);
    await type(tester, 'Hallo');

    await tapSend(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text(_generic), findsOneWidget);
    expect(fieldText(tester), 'Hallo');
    expect(
      tester
          .widget<FilterChip>(
            find.descendant(
              of: find.byKey(
                FeedbackScreen.categoryKey(FeedbackCategory.other),
              ),
              matching: find.byType(FilterChip),
            ),
          )
          .selected,
      isTrue,
    );
    expect(find.text(_thanks), findsNothing);
  });

  testWidgets('locks the form while sending', (tester) async {
    final answer = Completer<void>();
    service.answer = () => answer.future;
    await pump(tester);
    await choose(tester, FeedbackCategory.idea);
    await type(tester, 'Idee');

    await tapSend(tester);
    await tester.tap(find.byKey(FeedbackScreen.sendKey), warnIfMissed: false);
    await tester.pump();

    expect(service.sent, hasLength(1));
    expect(sendEnabled(tester), isFalse);
    expect(
      tester.widget<TextField>(find.byKey(FeedbackScreen.messageKey)).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(FeedbackScreen.replyKey))
          .onChanged,
      isNull,
    );
    await tester.tap(
      find.byKey(FeedbackScreen.categoryKey(FeedbackCategory.praise)),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.descendant(
              of: find.byKey(FeedbackScreen.categoryKey(FeedbackCategory.idea)),
              matching: find.byType(FilterChip),
            ),
          )
          .selected,
      isTrue,
    );

    answer.complete();
    await tester.pumpAndSettle();
    expect(service.sent, hasLength(1));
    expect(find.text(_thanks), findsOneWidget);
  });
}
