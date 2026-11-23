import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/knowledge_article.dart';
import '../services/knowledge/knowledge_feed_parser.dart';
import '../services/knowledge/knowledge_feed_service.dart';
import '../utils/logger.dart';

abstract class KnowledgeRepository {
  /// The blog's articles, newest first. Throws when the fetch fails or the
  /// feed is malformed.
  Future<List<KnowledgeArticle>> fetchArticles();

  /// The last good copy, or null when there is none or it is corrupt.
  Future<KnowledgeFeed?> readCache();

  Future<void> writeCache(KnowledgeFeed feed);
}

class HttpKnowledgeRepository implements KnowledgeRepository {
  static const _log = AppLogger('KnowledgeRepository');

  const HttpKnowledgeRepository(this._service);

  final KnowledgeFeedService _service;

  @override
  Future<List<KnowledgeArticle>> fetchArticles() async =>
      parseKnowledgeFeed(await _service.fetchFeed());

  @override
  Future<KnowledgeFeed?> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyKnowledgeFeedCache);
    if (raw == null) return null;
    try {
      return KnowledgeFeed.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (e) {
      _log.warn('Ignoring corrupt feed cache: $e');
      return null;
    }
  }

  @override
  Future<void> writeCache(KnowledgeFeed feed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyKnowledgeFeedCache,
      jsonEncode(feed.toJson()),
    );
  }
}

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (ref) => HttpKnowledgeRepository(ref.watch(knowledgeFeedServiceProvider)),
);
