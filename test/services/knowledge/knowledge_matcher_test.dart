import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/services/knowledge/knowledge_matcher.dart';
import 'package:belly_buddy/services/progress/progress_engine.dart';

import '../../helpers/fixtures.dart';

KnowledgeArticle _article(
  String title, {
  String? teaser,
  String? category,
  DateTime? at,
  String? slug,
}) => KnowledgeArticle(
  title: title,
  link: Uri.parse('https://www.myfodmap.at/${slug ?? title.hashCode}'),
  teaser: teaser,
  category: category,
  publishedAt: at,
);

Noticed _noticed(String name, {bool uncertain = false}) => Noticed(
  name: name,
  hard: 3,
  hardDays: 4,
  good: 0,
  goodDays: 5,
  uncertain: uncertain,
);

Insights _insights(List<Noticed> noticed, {bool unlocked = true}) => Insights(
  progress: InsightProgress(
    activeDays: unlocked ? 7 : 2,
    gutFeelingEntries: unlocked ? 3 : 1,
  ),
  calendar: const [],
  goodDays: const DayColumn(days: 0),
  hardDays: const DayColumn(days: 3),
  noticed: noticed,
  pick: const NothingYetPick(),
);

/// No symptoms and no intolerances: only the signals a test adds.
final _blank = testUserProfile(symptoms: [], intolerances: []);

var _ids = 0;

GutFeelingEntry _gut(DateTime at, {int bloating = 1, int? stress}) =>
    GutFeelingEntry(
      id: 'g${_ids++}',
      trackedAt: at,
      bloating: bloating,
      gas: 1,
      cramps: 1,
      fullness: 1,
      stress: stress,
    );

final _now = DateTime(2026, 11, 26, 10);
DateTime _nov(int day) => DateTime(2026, 11, day, 12);

RecentSignals _recent({
  List<GutFeelingEntry> guts = const [],
  List<int> stoolTypes = const [],
}) => computeProgress(
  ProgressSource(
    gutFeelings: guts,
    toilets: [
      for (final (i, s) in stoolTypes.indexed)
        (trackedAt: _nov(20 + i), stoolType: s),
    ],
    otherTimes: const [],
  ),
  now: _now,
).recent;

List<SignalKind> _kinds(List<ForYouSignal> s) => [for (final x in s) x.kind];

void main() {
  test('literal names are whole words', () {
    final signals = forYouSignals(
      profile: _blank,
      insights: _insights([_noticed('Reis'), _noticed('Zwiebel')]),
      includePatterns: true,
    );
    final waffle = _article('Reiswaffelbällchen mit Kakao');
    final onion = _article(
      'Ein Abend in der Küche',
      teaser: 'Wie es mit Zwiebel und Knoblauch geht',
    );
    final picks = pickForYou([waffle, onion], signals, opened: const {});
    expect(picks.map((p) => p.article), [onion]);
    expect(picks.single.reason, 'Weil Zwiebel bei dir auffällt');
    expect(picks.single.score, 5);
  });

  test('muster signals skip recipes', () {
    final onionRecipe = _article(
      'Quiche mit Zwiebel',
      category: 'Rezepte',
      slug: 'quiche',
    );
    final milkRecipe = _article(
      'Laktosefreier Kuchen',
      category: 'Rezepte',
      slug: 'kuchen',
    );
    final patterns = forYouSignals(
      profile: _blank,
      insights: _insights([_noticed('Zwiebel'), _noticed('Milch')]),
      includePatterns: true,
    );
    expect(
      pickForYou([onionRecipe, milkRecipe], patterns, opened: const {}),
      isEmpty,
    );

    final lactose = forYouSignals(
      profile: testUserProfile(symptoms: [], intolerances: ['Laktose']),
      includePatterns: true,
    );
    final picks = pickForYou([onionRecipe, milkRecipe], lactose, opened: {});
    expect(picks.map((p) => p.article), [milkRecipe]);
    expect(picks.single.reason, 'Weil du Laktose angegeben hast');
  });

  test(
    'uncertain and locked insights give no pattern signal; includePatterns false gives none',
    () {
      final uncertain = forYouSignals(
        insights: _insights([_noticed('Zwiebel', uncertain: true)]),
        includePatterns: true,
      );
      expect(uncertain, isEmpty);

      final locked = forYouSignals(
        insights: _insights([_noticed('Zwiebel')], unlocked: false),
        includePatterns: true,
      );
      expect(locked, isEmpty);

      final off = forYouSignals(
        insights: _insights([_noticed('Milch')]),
        includePatterns: false,
      );
      expect(off, isEmpty);

      // First 3 certain items, each literal plus its group.
      final four = forYouSignals(
        insights: _insights([
          _noticed('Lauch', uncertain: true),
          _noticed('Milch'),
          _noticed('Zwiebel'),
          _noticed('Brot, hell'),
          _noticed('Knoblauch'),
        ]),
        includePatterns: true,
      );
      expect(_kinds(four), [
        SignalKind.patternLiteral,
        SignalKind.patternGroup,
        SignalKind.patternLiteral,
        SignalKind.patternLiteral,
        SignalKind.patternGroup,
      ]);
      expect(four[1].keywords, ['laktose', 'milchzucker']);
      expect(four[4].keywords, ['gluten']);
      expect(four.map((s) => s.reason).toSet(), {
        'Weil Milch bei dir auffällt',
        'Weil Zwiebel bei dir auffällt',
        'Weil Brot, hell bei dir auffällt',
      });
    },
  );

  test('recent signals follow the thresholds', () {
    List<SignalKind> kinds(RecentSignals r) =>
        _kinds(forYouSignals(recent: r, includePatterns: true));

    final high = _recent(
      guts: [
        _gut(_nov(24), bloating: 3),
        _gut(_nov(25), bloating: 3),
        _gut(_nov(26), bloating: 3),
      ],
    );
    expect(high.means!.bloating, 3.0);
    expect(kinds(high), [SignalKind.recentSymptom]);

    // 2.9: just under.
    expect(
      kinds(
        const RecentSignals(
          means: SymptomMeans(bloating: 2.9, gas: 1, cramps: 1, fullness: 1),
          klo: 0,
          kloHard: 0,
          kloLoose: 0,
        ),
      ),
      isEmpty,
    );

    final two = _recent(
      guts: [_gut(_nov(25), bloating: 5), _gut(_nov(26), bloating: 5)],
    );
    expect(kinds(two), isEmpty);

    final stressed = _recent(
      guts: [
        _gut(_nov(24), stress: 3),
        _gut(_nov(25), stress: 3),
        _gut(_nov(26), stress: 3),
      ],
    );
    expect(kinds(stressed), [SignalKind.recentStress]);
    final twoStress = _recent(
      guts: [_gut(_nov(25), stress: 5), _gut(_nov(26), stress: 5)],
    );
    expect(kinds(twoStress), isEmpty);

    expect(kinds(_recent(stoolTypes: [1, 2, 3, 3])), [SignalKind.kloHard]);
    expect(kinds(_recent(stoolTypes: [1, 2, 3, 3, 3])), isEmpty);
    expect(kinds(_recent(stoolTypes: [1, 3])), isEmpty);
    expect(kinds(_recent(stoolTypes: [4, 5, 3, 3])), [SignalKind.kloLoose]);
    expect(kinds(_recent(stoolTypes: [4, 5, 3, 3, 3])), isEmpty);
    expect(kinds(_recent(stoolTypes: [5, 3])), isEmpty);
  });

  test(
    'score sums distinct signals; reason from the heaviest; ties by table order',
    () {
      final signals = forYouSignals(
        profile: testUserProfile(
          symptoms: ['Blähungen', 'Unangenehme Blähungen'],
          intolerances: ['Laktose', 'Laktose'],
        ),
        insights: _insights([_noticed('Milch')]),
        recent: _recent(
          guts: [
            for (final d in [24, 25, 26])
              GutFeelingEntry(
                id: 'b$d',
                trackedAt: _nov(d),
                bloating: 1,
                gas: 4,
                cramps: 1,
                fullness: 1,
              ),
          ],
        ),
        includePatterns: true,
      );
      // Duplicates (and the legacy spelling) give one signal each.
      expect(_kinds(signals), [
        SignalKind.patternLiteral,
        SignalKind.patternGroup,
        SignalKind.recentSymptom,
        SignalKind.intolerance,
        SignalKind.profileSymptom,
      ]);

      // Milchzucker (group 4 + intolerance 3), Blähungen (recent 4 + profile
      // 2), keyword twice in the text counts once.
      final both = _article(
        'Milchzucker und Blähungen',
        teaser: 'Blähungen nach Milchzucker',
        slug: 'both',
      );
      final pick = pickForYou([both], signals, opened: const {}).single;
      expect(pick.score, 4 + 3 + 4 + 2);
      // Group (4) and recent symptom (4) tie: the group comes first.
      expect(pick.reason, 'Weil Milch bei dir auffällt');

      final gasOnly = _article('Blähungen verstehen', slug: 'gas');
      final gasPick = pickForYou([gasOnly], signals, opened: const {}).single;
      expect(gasPick.score, 6);
      expect(
        gasPick.reason,
        'Weil du diese Woche öfter Blähungen eingetragen hast',
      );
    },
  );

  test(
    'order: score, then newest, then link; at most 3; opened links excluded',
    () {
      final signals = forYouSignals(
        profile: testUserProfile(
          symptoms: ['Verstopfung'],
          intolerances: ['Gluten'],
        ),
        includePatterns: true,
      );
      final top = _article(
        'Gluten und Verstopfung',
        at: DateTime.utc(2026, 1, 1),
        slug: 'top',
      );
      final newer = _article(
        'Glutenfrei backen',
        at: DateTime.utc(2026, 11, 1),
        slug: 'newer',
      );
      final olderB = _article(
        'Gluten im Alltag',
        at: DateTime.utc(2026, 6, 1),
        slug: 'b',
      );
      final olderA = _article(
        'Gluten unterwegs',
        at: DateTime.utc(2026, 6, 1),
        slug: 'a',
      );
      final undated = _article('Gluten ohne Datum', slug: 'undated');
      final none = _article('Hafer', slug: 'none');

      final picks = pickForYou(
        [undated, olderB, none, newer, olderA, top],
        signals,
        opened: const {},
      );
      expect(picks.map((p) => p.article), [top, newer, olderA]);

      final afterOpening = pickForYou(
        [undated, olderB, none, newer, olderA, top],
        signals,
        opened: {top.link.toString(), newer.link.toString()},
      );
      expect(afterOpening.map((p) => p.article), [olderA, olderB, undated]);
    },
  );

  test('no signal or no match → empty list', () {
    final articles = [_article('Hafer'), _article('Reis')];
    expect(pickForYou(articles, const [], opened: const {}), isEmpty);
    expect(forYouSignals(profile: _blank, includePatterns: true), isEmpty);
    expect(forYouSignals(includePatterns: true), isEmpty);
    final signals = forYouSignals(
      profile: testUserProfile(
        symptoms: ['Kopfschmerzen'],
        intolerances: ['Laktose'],
      ),
      includePatterns: true,
    );
    expect(_kinds(signals), [SignalKind.intolerance]);
    expect(pickForYou(articles, signals, opened: const {}), isEmpty);
    expect(pickForYou(const [], signals, opened: const {}), isEmpty);
  });

  test('reason strings', () {
    String reason(List<ForYouSignal> s, SignalKind kind) =>
        s.firstWhere((x) => x.kind == kind).reason;

    final patterns = forYouSignals(
      insights: _insights([_noticed('Zwiebel')]),
      includePatterns: true,
    );
    expect(
      reason(patterns, SignalKind.patternLiteral),
      'Weil Zwiebel bei dir auffällt',
    );

    final bloated = forYouSignals(
      recent: const RecentSignals(
        means: SymptomMeans(bloating: 3, gas: 1, cramps: 1, fullness: 1),
        klo: 0,
        kloHard: 0,
        kloLoose: 0,
      ),
      includePatterns: true,
    );
    expect(
      reason(bloated, SignalKind.recentSymptom),
      'Weil du diese Woche öfter Blähbauch eingetragen hast',
    );
    expect(bloated.single.keywords, ['blähbauch', 'blähung']);

    final week = forYouSignals(
      recent: const RecentSignals(stress: 3, klo: 4, kloHard: 2, kloLoose: 2),
      includePatterns: true,
    );
    expect(
      reason(week, SignalKind.recentStress),
      'Weil du diese Woche öfter gestresst warst',
    );
    expect(
      reason(week, SignalKind.kloHard),
      'Weil es beim Klo diese Woche öfter hart war',
    );
    expect(
      reason(week, SignalKind.kloLoose),
      'Weil es beim Klo diese Woche öfter weich war',
    );
    expect(week.firstWhere((s) => s.kind == SignalKind.kloHard).keywords, [
      'verstopf',
    ]);
    expect(week.firstWhere((s) => s.kind == SignalKind.kloLoose).keywords, [
      'durchfall',
    ]);

    final stated = forYouSignals(
      profile: testUserProfile(
        symptoms: ['Nervige Verstopfung'],
        intolerances: ['Laktose'],
      ),
      includePatterns: true,
    );
    expect(
      reason(stated, SignalKind.intolerance),
      'Weil du Laktose angegeben hast',
    );
    expect(
      reason(stated, SignalKind.profileSymptom),
      'Weil du Verstopfung angegeben hast',
    );

    expect(
      [for (final k in SignalKind.values) k.weight],
      [5, 4, 4, 4, 4, 4, 3, 2],
    );
  });
}
