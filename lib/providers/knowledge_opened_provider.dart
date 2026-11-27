import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// The links of the articles the signed-in user opened, oldest first, at
/// most [AppConstants.knowledgeOpenedMax]; kept per user and device under
/// `knowledge_opened_<userId>`. Empty while signed out. „Für dich" leaves
/// these out.
///
/// Preferences that can't be read or written are logged; the set then
/// lives in memory only.
class KnowledgeOpenedNotifier extends AsyncNotifier<Set<String>> {
  static const _log = AppLogger('KnowledgeOpened');

  /// The writes, one after another, so an older one never lands last.
  Future<void> _writes = Future.value();

  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};
    await _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(_key(userId))};
    } catch (e, st) {
      _log.error('Reading the opened articles failed', e, st);
      return const {};
    }
  }

  /// Adds [link] as the newest opened article (moving it there when it
  /// was opened before), drops the oldest beyond the maximum, and stores
  /// the list. Does nothing while signed out.
  Future<void> markOpened(Uri link) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final opRef = ref;
    final Set<String> current;
    try {
      current = await future;
    } catch (_) {
      return;
    }
    if (!opRef.isCurrentUser(userId)) return;
    final url = link.toString();
    final list = [...current.where((l) => l != url), url];
    final kept = list.length > AppConstants.knowledgeOpenedMax
        ? list.sublist(list.length - AppConstants.knowledgeOpenedMax)
        : list;
    state = AsyncData(kept.toSet());
    final key = _key(userId);
    await (_writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(key, kept);
      } catch (e, st) {
        _log.error('Storing the opened articles failed', e, st);
      }
    }));
  }

  static String _key(String userId) =>
      '${AppConstants.keyKnowledgeOpenedPrefix}$userId';
}

final knowledgeOpenedProvider =
    AsyncNotifierProvider<KnowledgeOpenedNotifier, Set<String>>(
      KnowledgeOpenedNotifier.new,
    );
