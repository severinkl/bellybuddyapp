import 'dart:convert';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/services/knowledge/knowledge_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('200 returns the body decoded as UTF-8', () async {
    final service = KnowledgeFeedService(
      MockClient(
        (_) async => http.Response.bytes(utf8.encode('Persönliches'), 200),
      ),
    );
    expect(await service.fetchFeed(), 'Persönliches');
  });

  test('a non-200 status throws', () async {
    final service = KnowledgeFeedService(
      MockClient((_) async => http.Response('nope', 500)),
    );
    await expectLater(service.fetchFeed(), throwsA(isA<Exception>()));
  });

  test('slower than the timeout throws', () async {
    final service = KnowledgeFeedService(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('late', 200);
      }),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(service.fetchFeed(), throwsA(isA<Exception>()));
  });

  test('requests exactly the feed URL', () async {
    Uri? requested;
    final service = KnowledgeFeedService(
      MockClient((request) async {
        requested = request.url;
        return http.Response('ok', 200);
      }),
    );
    await service.fetchFeed();
    expect(requested, Uri.parse(AppConstants.knowledgeFeedUrl));
  });
}
