import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every mood has a preset and a non-empty label', () {
    for (final m in BuddyMood.values) {
      expect(FacePose.forMood(m), isA<FacePose>());
      expect(buddyMoodLabel(m), isNotEmpty);
    }
    expect(buddyMoodLabel(BuddyMood.sleepy), 'verschlafen');
    expect(buddyMoodLabel(BuddyMood.empathetic), 'mitfühlend');
  });

  test('lerp endpoints match for all mood pairs', () {
    for (final a in BuddyMood.values) {
      for (final b in BuddyMood.values) {
        final pa = FacePose.forMood(a), pb = FacePose.forMood(b);
        expect(FacePose.lerp(pa, pb, 0).closeTo(pa), isTrue);
        expect(FacePose.lerp(pa, pb, 1).closeTo(pb), isTrue);
      }
    }
  });

  test('lerp midpoint', () {
    final p = FacePose.lerp(
      FacePose.forMood(BuddyMood.happy),
      FacePose.forMood(BuddyMood.sad),
      0.5,
    );
    expect(p.smile, closeTo(0.15, 1e-9));
  });

  test('presets are pairwise distinct', () {
    const v = BuddyMood.values;
    for (var i = 0; i < v.length; i++) {
      for (var j = i + 1; j < v.length; j++) {
        expect(
          FacePose.forMood(v[i]).closeTo(FacePose.forMood(v[j])),
          isFalse,
          reason: '${v[i]} vs ${v[j]}',
        );
      }
    }
  });

  test('copyWith changes only the given field', () {
    const base = FacePose();
    final c = base.copyWith(smile: -1);
    expect(c.smile, -1);
    expect(FacePose.lerp(base, c, 1).closeTo(c), isTrue);
    expect(c.copyWith(smile: base.smile).closeTo(base), isTrue);
    expect(base.copyWith(zzz: 1).zzz, 1);
    expect(base.copyWith(lean: 0.5).lean, 0.5);
    expect(base.copyWith(rumble: 0.5).rumble, 0.5);
  });
}
