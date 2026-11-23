import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../config/constants.dart';

/// Fetches the raw myfodmap blog feed.
class KnowledgeFeedService {
  const KnowledgeFeedService(
    this._client, {
    this.timeout = AppConstants.knowledgeFeedTimeout,
  });

  final http.Client _client;
  final Duration timeout;

  /// The feed's XML. Throws on a non-200 status or when it takes longer than
  /// [timeout].
  Future<String> fetchFeed() async {
    final response = await _client
        .get(Uri.parse(AppConstants.knowledgeFeedUrl))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Feed answered ${response.statusCode}',
        Uri.parse(AppConstants.knowledgeFeedUrl),
      );
    }
    return utf8.decode(response.bodyBytes);
  }
}

final knowledgeFeedServiceProvider = Provider<KnowledgeFeedService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return KnowledgeFeedService(client);
});
