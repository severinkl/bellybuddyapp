import 'package:belly_buddy/models/dietitian_card.dart';
import 'package:belly_buddy/models/dietitian_tip.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';

/// A [DietitianTip] with defaults: a new tip from Julia Berger.
DietitianTip testTip({
  String id = 't1',
  String sender = 'Julia Berger',
  DietitianProfession profession = DietitianProfession.dietologin,
  String body = 'Probier Haferflocken am Morgen.',
  DateTime? createdAt,
  DateTime? seenAt,
  DateTime? tryingAt,
}) => DietitianTip(
  id: id,
  senderName: sender,
  senderProfession: profession,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 26, 8),
  seenAt: seenAt,
  tryingAt: tryingAt,
);

/// A [DietitianTipService] that answers from memory.
class FakeDietitianTipService implements DietitianTipService {
  FakeDietitianTipService([List<DietitianTip> tips = const []])
    : tips = List.of(tips);

  List<DietitianTip> tips;
  bool failList = false;
  bool failWrite = false;
  int listCalls = 0;
  final List<List<String>> seenCalls = [];
  final List<(String, bool)> tryingCalls = [];
  final List<String> removed = [];

  @override
  Future<List<DietitianTip>> list() async {
    listCalls++;
    if (failList) throw Exception('offline');
    return List.of(tips);
  }

  @override
  Future<void> markSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    if (failWrite) throw Exception('offline');
    seenCalls.add(ids);
    final now = DateTime.now().toUtc();
    tips = [
      for (final t in tips)
        ids.contains(t.id) && t.isNew ? t.copyWith(seenAt: now) : t,
    ];
  }

  @override
  Future<void> setTrying(String id, bool trying) async {
    if (failWrite) throw Exception('offline');
    tryingCalls.add((id, trying));
    tips = [
      for (final t in tips)
        t.id == id
            ? t.copyWith(tryingAt: trying ? DateTime.now().toUtc() : null)
            : t,
    ];
  }

  @override
  Future<void> remove(String id) async {
    if (failWrite) throw Exception('offline');
    removed.add(id);
    tips = [
      for (final t in tips)
        if (t.id != id) t,
    ];
  }
}
