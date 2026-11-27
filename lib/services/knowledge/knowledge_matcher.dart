import '../../config/constants.dart';
import '../../config/symptom_options.dart';
import '../../models/insights.dart';
import '../../models/knowledge_article.dart';
import '../../models/progress.dart';
import '../../models/progress_rules.dart';
import '../../models/user_profile.dart';
import 'knowledge_keywords.dart';

/// What a „Für dich" signal comes from, in the order of spec §4.2's table
/// (the tie order of reasons), with its weight.
enum SignalKind {
  /// A Muster item's name, as a whole word.
  patternLiteral(5),

  /// A Muster item's ingredient group ([KnowledgeKeywords.groupOf]).
  patternGroup(4),

  /// A symptom with a recent mean of at least [ProgressRules.recentHigh].
  recentSymptom(4),

  /// A recent stress mean of at least [ProgressRules.recentHigh].
  recentStress(4),

  /// Hard Klo entries this week: at least [ProgressRules.kloMin], at least
  /// half of them.
  kloHard(4),

  /// Loose Klo entries this week, likewise.
  kloLoose(4),

  /// An intolerance of the profile.
  intolerance(3),

  /// A symptom of the profile.
  profileSymptom(2);

  const SignalKind(this.weight);

  final int weight;

  bool get isPattern => this == patternLiteral || this == patternGroup;
}

/// One reason an article may be „Für dich": keywords, weight and the
/// line shown under the article.
class ForYouSignal {
  const ForYouSignal(this.kind, this.keywords, this.reason);

  final SignalKind kind;

  /// Lower case; any of them at a word start (whole words for
  /// [SignalKind.patternLiteral]) matches.
  final List<String> keywords;

  /// „Weil …", what the user logged or stated; never a diagnosis.
  final String reason;

  int get weight => kind.weight;

  bool get wholeWord => kind == SignalKind.patternLiteral;

  /// Whether this signal matches [article], whose lower-case title + teaser
  /// is [text].
  bool matches(KnowledgeArticle article, String text) {
    if (kind.isPattern &&
        article.category == KnowledgeKeywords.recipeCategory) {
      return false;
    }
    return keywords.any(
      (k) => wholeWord
          ? KnowledgeKeywords.matchesWholeWord(text, k)
          : KnowledgeKeywords.matchesAtWordStart(text, k),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ForYouSignal &&
      other.kind == kind &&
      other.reason == reason &&
      _listEquals(other.keywords, keywords);

  @override
  int get hashCode => Object.hash(kind, reason, Object.hashAll(keywords));

  @override
  String toString() => 'ForYouSignal(${kind.name}, $keywords, $reason)';
}

/// An article picked „Für dich", with the reason shown under it.
class ForYouPick {
  const ForYouPick({
    required this.article,
    required this.reason,
    required this.score,
  });

  final KnowledgeArticle article;
  final String reason;

  /// The sum of the weights of the distinct matching signals.
  final int score;

  @override
  bool operator ==(Object other) =>
      other is ForYouPick &&
      other.article == article &&
      other.reason == reason &&
      other.score == score;

  @override
  int get hashCode => Object.hash(article, reason, score);

  @override
  String toString() => 'ForYouPick(${article.link}, $score, $reason)';
}

/// The „Für dich" signals of what the app holds, in table order (spec
/// §4.2), each once. The Muster items (the unlocked [insights]' first 3
/// „Fällt mir auf" items that are not uncertain) count only with
/// [includePatterns].
List<ForYouSignal> forYouSignals({
  UserProfile? profile,
  Insights? insights,
  RecentSignals? recent,
  required bool includePatterns,
}) {
  final signals = <ForYouSignal>{};

  if (includePatterns && insights != null && insights.unlocked) {
    for (final item in insights.noticed.where((n) => !n.uncertain).take(3)) {
      final reason = 'Weil ${item.name} bei dir auffällt';
      signals.add(
        ForYouSignal(SignalKind.patternLiteral, [
          item.name.trim().toLowerCase(),
        ], reason),
      );
      final group = KnowledgeKeywords.groupOf(item.name);
      if (group != null) {
        signals.add(
          ForYouSignal(
            SignalKind.patternGroup,
            KnowledgeKeywords.intolerances[group]!,
            reason,
          ),
        );
      }
    }
  }

  if (recent != null) {
    bool high(double? mean) => mean != null && mean >= ProgressRules.recentHigh;
    bool often(int n) => n >= ProgressRules.kloMin && n * 2 >= recent.klo;

    if (recent.means case final m?) {
      final [bloating, gas, cramps, fullness] = AppConstants.gutFeelingSymptoms;
      for (final (symptom, mean) in [
        (bloating, m.bloating),
        (gas, m.gas),
        (cramps, m.cramps),
        (fullness, m.fullness),
      ]) {
        if (high(mean)) {
          signals.add(
            ForYouSignal(
              SignalKind.recentSymptom,
              KnowledgeKeywords.symptoms[symptom]!,
              'Weil du diese Woche öfter $symptom eingetragen hast',
            ),
          );
        }
      }
    }
    if (high(recent.stress)) {
      signals.add(
        ForYouSignal(
          SignalKind.recentStress,
          KnowledgeKeywords.symptoms['Stress']!,
          'Weil du diese Woche öfter gestresst warst',
        ),
      );
    }
    if (often(recent.kloHard)) {
      signals.add(
        ForYouSignal(
          SignalKind.kloHard,
          KnowledgeKeywords.symptoms['Verstopfung']!,
          'Weil es beim Klo diese Woche öfter hart war',
        ),
      );
    }
    if (often(recent.kloLoose)) {
      signals.add(
        ForYouSignal(
          SignalKind.kloLoose,
          KnowledgeKeywords.symptoms['Durchfall']!,
          'Weil es beim Klo diese Woche öfter weich war',
        ),
      );
    }
  }

  if (profile != null) {
    for (final intolerance in profile.intolerances) {
      if (KnowledgeKeywords.intolerances[intolerance] case final keywords?) {
        signals.add(
          ForYouSignal(
            SignalKind.intolerance,
            keywords,
            'Weil du $intolerance angegeben hast',
          ),
        );
      }
    }
    final known = {for (final s in kSymptomOptions) s.value};
    for (final symptom in normalizeSymptoms(profile.symptoms)) {
      if (!known.contains(symptom)) continue;
      if (KnowledgeKeywords.symptoms[symptom] case final keywords?) {
        signals.add(
          ForYouSignal(
            SignalKind.profileSymptom,
            keywords,
            'Weil du ${symptomLabel(symptom)} angegeben hast',
          ),
        );
      }
    }
  }

  return signals.toList();
}

/// At most this many picks.
const forYouMax = 3;

/// The articles „Für dich": those [signals] match and whose link is not in
/// [opened], by score (desc), then newest (undated last), then link; at
/// most [forYouMax]. Each with the reason of its heaviest matching signal
/// (ties: table order, then [signals]' order).
List<ForYouPick> pickForYou(
  List<KnowledgeArticle> articles,
  List<ForYouSignal> signals, {
  required Set<String> opened,
}) {
  if (signals.isEmpty) return const [];
  final distinct = signals.toSet().toList();
  // Heaviest first, so the first match gives the reason.
  final byWeight = [...distinct.indexed]
    ..sort((x, y) {
      final c = y.$2.weight.compareTo(x.$2.weight);
      if (c != 0) return c;
      final k = x.$2.kind.index.compareTo(y.$2.kind.index);
      return k != 0 ? k : x.$1.compareTo(y.$1);
    });

  final picks = <ForYouPick>[];
  for (final article in articles) {
    if (opened.contains(article.link.toString())) continue;
    final text = '${article.title} ${article.teaser ?? ''}'.toLowerCase();
    String? reason;
    var score = 0;
    for (final (_, signal) in byWeight) {
      if (!signal.matches(article, text)) continue;
      reason ??= signal.reason;
      score += signal.weight;
    }
    if (reason != null) {
      picks.add(ForYouPick(article: article, reason: reason, score: score));
    }
  }

  picks.sort((x, y) {
    final s = y.score.compareTo(x.score);
    if (s != 0) return s;
    final dx = x.article.publishedAt, dy = y.article.publishedAt;
    if (dx != dy) {
      if (dx == null) return 1;
      if (dy == null) return -1;
      return dy.compareTo(dx);
    }
    return x.article.link.toString().compareTo(y.article.link.toString());
  });
  return picks.take(forYouMax).toList();
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
