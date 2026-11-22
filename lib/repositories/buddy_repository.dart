import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/buddy_state.dart';
import '../services/buddy_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

abstract class BuddyRepository {
  Future<BuddyState?> fetch(String userId);
  Future<void> save(String userId, BuddyState state);
}

class SupabaseBuddyRepository implements BuddyRepository {
  static const _log = AppLogger('BuddyRepository');
  final BuddyService _service;
  SupabaseBuddyRepository(this._service);

  @override
  Future<BuddyState?> fetch(String userId) async {
    final data = await retryAsync(
      () => _service.fetchByUserId(userId),
      log: _log,
      label: 'fetchBuddyState',
    );
    if (data == null) return null;
    return BuddyState.fromJson(data);
  }

  @override
  Future<void> save(String userId, BuddyState state) async {
    final data = state.toJson();
    data.remove('id');
    data.remove('updated_at');
    data['user_id'] = userId;
    data['onboarding_completed_at'] = state.onboardingCompletedAt
        ?.toUtc()
        .toIso8601String();
    await _service.upsert(data);
  }
}

/// Dev-only store (build with `--dart-define=BUDDY_LOCAL_STATE=true`).
class LocalBuddyRepository implements BuddyRepository {
  const LocalBuddyRepository();

  String _key(String userId) => '${AppConstants.keyBuddyStatePrefix}$userId';

  @override
  Future<BuddyState?> fetch(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    return BuddyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(String userId, BuddyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode(state.copyWith(userId: userId).toJson()),
    );
  }
}

final buddyRepositoryProvider = Provider<BuddyRepository>(
  (ref) => const bool.fromEnvironment('BUDDY_LOCAL_STATE')
      ? const LocalBuddyRepository()
      : SupabaseBuddyRepository(ref.watch(buddyServiceProvider)),
);
