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

  /// The last good copy, or null when there is none, it is corrupt or it
  /// can't be read. Never throws.
  Future<KnowledgeFeed?> readCache();

  Future<void> writeCache(KnowledgeFeed feed);
}

class HttpKnowledgeRepository implements KnowledgeRepository {
  static const _log = AppLogger('KnowledgeRepository');

  const HttpKnowledgeRepository(
    this._service, {
    Future<SharedPreferences> Function() preferences =
        SharedPreferences.getInstance,
  }) : _preferences = preferences;

  final KnowledgeFeedService _service;

  /// Opens the preferences the cache lives in.
  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<List<KnowledgeArticle>> fetchArticles() async =>
      parseKnowledgeFeed(await _service.fetchFeed());

  @override
  Future<KnowledgeFeed?> readCache() async {
    final String? raw;
    try {
      final prefs = await _preferences();
      raw = prefs.getString(AppConstants.keyKnowledgeFeedCache);
    } on Object catch (e, st) {
      _log.error('Reading the feed cache failed', e, st);
      return null;
    }
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
    final prefs = await _preferences();
    await prefs.setString(
      AppConstants.keyKnowledgeFeedCache,
      jsonEncode(feed.toJson()),
    );
  }
}

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (ref) => HttpKnowledgeRepository(ref.watch(knowledgeFeedServiceProvider)),
);
