import 'dart:ui';

import 'package:belly_buddy/widgets/buddy/buddy_geometry.dart';
import 'package:belly_buddy/widgets/buddy/buddy_shape_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subdivide keeps endpoints', () {
    final out = subdivideBuddyPath(kBuddySilhouette);
    expect(out[0], 0);
    expect(out[1], closeTo(kBuddySilhouette[1], 0.01));
    expect(out[2], closeTo(kBuddySilhouette[2], 0.01));
    // Endpoint preceding each close must be unchanged.
    List<Offset> closers(List<double> d) {
      final res = <Offset>[];
      var i = 0;
      var last = Offset.zero;
      while (i < d.length) {
        final op = d[i].toInt();
        i++;
        switch (op) {
          case 0:
          case 1:
            last = Offset(d[i], d[i + 1]);
            i += 2;
          case 2:
            last = Offset(d[i + 4], d[i + 5]);
            i += 6;
          default:
            res.add(last);
        }
      }
      return res;
    }

    final a = closers(kBuddySilhouette);
    final b = closers(out);
    expect(b.length, a.length);
    for (var k = 0; k < a.length; k++) {
      expect((a[k] - b[k]).distance, lessThan(0.01));
    }
  });

  test('subdivide bounds piece length', () {
    final out = subdivideBuddyPath(kBuddySilhouette);
    var i = 0;
    var p = Offset.zero;
    while (i < out.length) {
      final op = out[i].toInt();
      i++;
      if (op == 0) {
        p = Offset(out[i], out[i + 1]);
        i += 2;
      } else if (op == 2) {
        final c1 = Offset(out[i], out[i + 1]);
        final c2 = Offset(out[i + 2], out[i + 3]);
        final e = Offset(out[i + 4], out[i + 5]);
        final len = (c1 - p).distance + (c2 - c1).distance + (e - c2).distance;
        expect(len, lessThanOrEqualTo(45.5));
        p = e;
        i += 6;
      }
    }
  });

  test('hitPath contains body but not outside', () {
    final hit = BuddyShapes.hitPath;
    expect(hit.contains(const Offset(900, 420)), isTrue);
    expect(hit.contains(const Offset(815, 1850)), isTrue);
    expect(hit.contains(const Offset(20, 20)), isFalse);
    expect(hit.contains(const Offset(1400, 1900)), isFalse);
  });

  test('layout round-trips', () {
    final l = BuddyLayout(const Size(390, 600));
    const p = Offset(123, 456);
    final r = l.toLocal(l.toImage(p));
    expect((r - p).distance, lessThan(1e-6));
  });

  test('layout zero size', () {
    expect(BuddyLayout(Size.zero).scale, 0);
  });

  test('centerline endpoints', () {
    expect(pointAlongCenterline(0), const Offset(430, 0));
    expect(pointAlongCenterline(1), const Offset(840, 1920));
    expect(pointAlongCenterline(-1), const Offset(430, 0));
    expect(kBuddyCenterline.length, 24);
  });
}
