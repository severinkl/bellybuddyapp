import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/models/dietitian_card.dart';
import 'package:belly_buddy/services/share_service.dart';

/// A [DataShare] with defaults: an active, unopened 14-day share.
DataShare testShare({
  String id = 's1',
  String name = 'Dr. A',
  SharePeriod period = SharePeriod.days14,
  bool photos = false,
  DateTime? createdAt,
  DateTime? expiresAt,
  DateTime? revokedAt,
  DateTime? lockedAt,
  DateTime? lastOpenedAt,
  int openCount = 0,
}) => DataShare(
  id: id,
  displayName: name,
  period: period,
  shareMeals: true,
  shareDrinks: true,
  shareGut: true,
  shareToilet: true,
  sharePatterns: false,
  sharePhotos: photos,
  createdAt: createdAt ?? DateTime(2026, 11, 20, 10),
  expiresAt: expiresAt ?? DateTime(2026, 12, 20, 10),
  revokedAt: revokedAt,
  lockedAt: lockedAt,
  lastOpenedAt: lastOpenedAt,
  openCount: openCount,
);

/// A [ShareService] that answers from memory.
class FakeShareService implements ShareService {
  FakeShareService([List<DataShare> shares = const []])
    : shares = List.of(shares);

  List<DataShare> shares;
  bool failList = false;
  bool failEnd = false;
  bool failCreate = false;
  int listCalls = 0;
  final List<String> ended = [];

  @override
  Future<List<DataShare>> list() async {
    listCalls++;
    if (failList) throw Exception('offline');
    return List.of(shares);
  }

  @override
  Future<CreatedShare> create(NewShare share) async {
    if (failCreate) throw const ShareException();
    final created = CreatedShare(
      id: 'new1',
      link: 'https://example.test/s/abc',
      code: '482913',
      expiresAt: DateTime(2026, 12, 20),
    );
    shares = [testShare(id: created.id, name: share.displayName), ...shares];
    return created;
  }

  @override
  Future<void> end(String id) async {
    if (failEnd) throw const ShareException();
    ended.add(id);
    shares = [
      for (final s in shares)
        s.id == id ? s.copyWith(revokedAt: DateTime(2026, 11, 26)) : s,
    ];
  }

  @override
  Future<DietitianCard> lookup(String code) =>
      throw UnimplementedError('lookup');

  @override
  Future<String> connect(String code, DietitianShareTerms terms) =>
      throw UnimplementedError('connect');

  @override
  Future<void> update(String id, DietitianShareTerms terms) =>
      throw UnimplementedError('update');
}
