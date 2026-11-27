import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/data_share.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

/// Link and code of the user's shares, kept on this device (core stores only
/// hashes). Keys are namespaced by user id so two accounts on one device
/// never see each other's. Never logs link, code or token.
class ShareSecretsStore {
  ShareSecretsStore({required String? Function() userId}) : _userId = userId;

  final String? Function() _userId;

  static const _log = AppLogger('ShareSecretsStore');

  static String _secretPrefix(String uid) => 'share_secret.$uid.';
  static String _nameKey(String uid) => 'share_display_name.$uid';

  Future<void> save(String shareId, ShareSecret secret) async {
    final uid = _userId();
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_secretPrefix(uid)}$shareId',
      jsonEncode({'link': secret.link, 'code': secret.code}),
    );
  }

  Future<ShareSecret?> read(String shareId) async {
    final uid = _userId();
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_secretPrefix(uid)}$shareId');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ShareSecret(
        link: json['link'] as String,
        code: json['code'] as String,
      );
    } catch (_) {
      _log.warn('unreadable stored secret ignored');
      return null;
    }
  }

  Future<void> remove(String shareId) async {
    final uid = _userId();
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_secretPrefix(uid)}$shareId');
  }

  /// Removes all share secrets of [userId] and the remembered display name.
  /// For sign-out and account deletion, when the signed-in user is already
  /// gone. Attempts every key, then rethrows the first failure.
  Future<void> clearFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _secretPrefix(userId);
    final keys = [
      ...prefs.getKeys().where((k) => k.startsWith(prefix)),
      _nameKey(userId),
    ];
    // Waits for every removal, then rethrows the first failure.
    await Future.wait(keys.map(prefs.remove));
  }

  Future<String?> lastDisplayName() async {
    final uid = _userId();
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey(uid));
  }

  Future<void> rememberDisplayName(String name) async {
    final uid = _userId();
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey(uid), name);
  }
}

final shareSecretsStoreProvider = Provider<ShareSecretsStore>(
  (ref) => ShareSecretsStore(userId: () => ref.read(currentUserIdProvider)),
);
