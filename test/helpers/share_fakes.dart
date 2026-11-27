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
  ShareKind kind = ShareKind.link,
  String? dietitianId,
  DietitianCard? dietitian,
  DietitianCard? keeper,
  String? keptBy,
  bool openEnded = false,
  bool meals = true,
  bool drinks = true,
  bool gut = true,
  bool toilet = true,
  bool patterns = false,
}) => DataShare(
  id: id,
  displayName: name,
  period: period,
  shareMeals: meals,
  shareDrinks: drinks,
  shareGut: gut,
  shareToilet: toilet,
  sharePatterns: patterns,
  sharePhotos: photos,
  createdAt: createdAt ?? DateTime(2026, 11, 20, 10),
  expiresAt: openEnded ? null : expiresAt ?? DateTime(2026, 12, 20, 10),
  revokedAt: revokedAt,
  lockedAt: lockedAt,
  lastOpenedAt: lastOpenedAt,
  openCount: openCount,
  kind: kind,
  dietitianId: dietitianId,
  dietitian: dietitian,
  keeper: keeper,
  keptBy: keptBy,
);

/// A dietitian card: „Diätolog:in (eigene Angabe) · Praxis Berger, Innsbruck".
DietitianCard testCard({String name = 'Anna Berger', DateTime? blockedAt}) =>
    DietitianCard(
      name: name,
      profession: DietitianProfession.dietologin,
      practice: 'Praxis Berger',
      town: 'Innsbruck',
      blockedAt: blockedAt,
    );

/// A connection to a dietitian (open-ended unless [expiresAt] is given).
DataShare testDietitianShare({
  String id = 'd1',
  DietitianCard? dietitian,
  String? dietitianId = 'dt1',
  DateTime? createdAt,
  DateTime? expiresAt,
  DateTime? revokedAt,
  DateTime? lastOpenedAt,
  bool photos = false,
  bool meals = true,
  bool drinks = true,
  bool gut = true,
  bool toilet = true,
  bool patterns = true,
}) => testShare(
  id: id,
  kind: ShareKind.dietitian,
  dietitianId: dietitianId,
  dietitian: dietitianId == null ? null : dietitian ?? testCard(),
  openEnded: expiresAt == null,
  expiresAt: expiresAt,
  createdAt: createdAt ?? DateTime(2026, 11, 5, 10),
  revokedAt: revokedAt,
  lastOpenedAt: lastOpenedAt,
  photos: photos,
  meals: meals,
  drinks: drinks,
  gut: gut,
  toilet: toilet,
  patterns: patterns,
);

/// A [ShareService] that answers from memory.
class FakeShareService implements ShareService {
  FakeShareService([List<DataShare> shares = const []])
    : shares = List.of(shares);

  List<DataShare> shares;
  bool failList = false;
  bool failEnd = false;
  bool failCreate = false;
  bool failUpdate = false;
  bool failConnect = false;
  final List<(String, DietitianShareTerms)> updated = [];
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
  Future<String> connect(String code, DietitianShareTerms terms) async {
    if (failConnect) throw const ShareException();
    shares = [testDietitianShare(id: 'c1'), ...shares];
    return 'c1';
  }

  @override
  Future<void> update(String id, DietitianShareTerms terms) async {
    if (failUpdate) throw const ShareException();
    updated.add((id, terms));
    shares = [
      for (final s in shares)
        s.id == id
            ? s.copyWith(
                displayName: terms.displayName,
                shareMeals: terms.meals,
              )
            : s,
    ];
  }
}
