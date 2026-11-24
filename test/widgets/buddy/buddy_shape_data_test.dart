import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/buddy/buddy_shape_data.dart';

/// Number of coordinate values following each opcode.
/// 0=moveTo(x,y) 1=lineTo(x,y) 2=cubicTo(x1,y1,x2,y2,x,y) 3=close.
const Map<int, int> _argCounts = {0: 2, 1: 2, 2: 6, 3: 0};

/// Walks an opcode-encoded list and returns the number of values consumed.
/// Returns -1 if the list is malformed (unknown opcode or truncated args).
int _decodeLength(List<double> data) {
  var i = 0;
  while (i < data.length) {
    final op = data[i].toInt();
    final argCount = _argCounts[op];
    if (argCount == null) return -1;
    if (i + 1 + argCount > data.length) return -1;
    i += 1 + argCount;
  }
  return i;
}

/// A coordinate with its role: on-curve point or cubic control handle.
typedef _Point = ({double x, double y, bool isControl});

/// Collects coordinates from an opcode-encoded list. Cubic control handles
/// (first two pairs of opcode 2) are flagged so they can use a looser margin.
List<_Point> _points(List<double> data) {
  final points = <_Point>[];
  var i = 0;
  while (i < data.length) {
    final op = data[i].toInt();
    final argCount = _argCounts[op]!;
    final args = data.sublist(i + 1, i + 1 + argCount);
    for (var j = 0; j + 1 < args.length; j += 2) {
      final isControl = op == 2 && j < 4;
      points.add((x: args[j], y: args[j + 1], isControl: isControl));
    }
    i += 1 + argCount;
  }
  return points;
}

void main() {
  final layers = <String, List<double>>{
    'kBuddySilhouette': kBuddySilhouette,
    'kBuddyFill': kBuddyFill,
    'kBuddyOutline': kBuddyOutline,
  };

  for (final entry in layers.entries) {
    group(entry.key, () {
      test('is non-empty and starts with moveTo', () {
        expect(entry.value, isNotEmpty);
        expect(entry.value.first.toInt(), 0);
      });

      test('decodes to exactly its own length (no truncation)', () {
        expect(_decodeLength(entry.value), entry.value.length);
      });

      test('on-curve points lie within the canvas plus a 5px margin', () {
        const margin = 5.0;
        for (final p in _points(entry.value).where((p) => !p.isControl)) {
          expect(p.x, inInclusiveRange(-margin, kBuddyWidth + margin));
          expect(p.y, inInclusiveRange(-margin, kBuddyHeight + margin));
        }
      });

      test('cubic control handles lie within a 100px margin', () {
        const margin = 100.0;
        for (final p in _points(entry.value).where((p) => p.isControl)) {
          expect(p.x, inInclusiveRange(-margin, kBuddyWidth + margin));
          expect(p.y, inInclusiveRange(-margin, kBuddyHeight + margin));
        }
      });
    });
  }
}
