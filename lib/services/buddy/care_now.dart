import '../../utils/gut_feeling_rating.dart';
import '../../widgets/buddy/buddy_pose.dart';
import 'buddy_mood_logic.dart';
import 'care_meters.dart';
import 'daily_care.dart';

/// What Home shows of the Buddy's needs ([log]) at one minute ([at]): the
/// meters, his mood, the next action and what the bubbles say. Equal to
/// another whenever all of that is the same (whatever [at] and [log]), so
/// Home only rebuilds when something it shows changed.
class CareNow {
  CareNow._(
    this.log,
    this.at, {
    required this.meters,
    required this.mood,
    required this.action,
    required List<String> spoken,
  }) : _spoken = spoken;

  factory CareNow.at(CareLog log, DateTime at) => CareNow._(
    log,
    at,
    meters: CareMeters.at(log, at),
    mood: deriveBuddyMood(log, at),
    action: nextCareAction(log, at),
    spoken: [
      for (final need in CareNeed.values) CareCopy.spoken(need, log, at),
    ],
  );

  final CareLog log;
  final DateTime at;
  final CareMeters meters;
  final BuddyMood mood;
  final CareAction action;

  /// [CareCopy.spoken] per need, in [CareNeed.values] order.
  final List<String> _spoken;

  /// [need]'s semantics value ([CareCopy.spoken]).
  String spoken(CareNeed need) => _spoken[need.index];

  /// Klo's line ([CareCopy.looLine]).
  String get looLine => CareCopy.looLine(log, at);

  /// How today's latest Bauchgefühl was; its bubble shows the face.
  GutFeelingRatingLevel? get gutFeelingLevel => log.lastGutFeelingLevel;

  @override
  bool operator ==(Object other) =>
      other is CareNow &&
      other.meters == meters &&
      other.mood == mood &&
      other.action == action &&
      other.gutFeelingLevel == gutFeelingLevel &&
      _sameSpoken(other);

  bool _sameSpoken(CareNow other) {
    for (var i = 0; i < _spoken.length; i++) {
      if (other._spoken[i] != _spoken[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    meters,
    mood,
    action,
    gutFeelingLevel,
    Object.hashAll(_spoken),
  );
}
