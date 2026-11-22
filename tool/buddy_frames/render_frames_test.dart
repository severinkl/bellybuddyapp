// Local review renders of the animated Buddy (not run in CI).
// Run: flutter test tool/buddy_frames/render_frames_test.dart --update-goldens
// PNGs land in tool/buddy_frames/frames/ (gitignored); build a contact sheet
// with tool/buddy_trace/sheet.py.
import 'dart:ui' as ui;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _size = Size(400, 520);
const _fps = 60;

void main() {
  Future<void> shoot(
    WidgetTester tester,
    String name,
    BuddyController c,
  ) async {
    await tester.binding.setSurfaceSize(_size);
    await tester.pumpWidget(
      RepaintBoundary(
        child: ColoredBox(
          color: AppTheme.screenBackground,
          child: CustomPaint(size: _size, painter: BuddyPainter(c)),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('frames/$name.png'),
    );
  }

  void run(BuddyController c, double seconds) {
    for (var i = 0; i < (seconds * _fps).round(); i++) {
      c.tick(1 / _fps);
    }
  }

  for (final m in BuddyMood.values) {
    for (final at in [3.3, 4.4]) {
      testWidgets('mood ${m.name} $at', (tester) async {
        final c = BuddyController(mood: m);
        run(c, at);
        await shoot(tester, 'mood_${m.name}_$at', c);
      });
    }
  }

  /// Mood each action is shown from (its typical context).
  BuddyMood from(BuddyAction a) => switch (a) {
    BuddyAction.wakeUp || BuddyAction.yawn => BuddyMood.sleepy,
    BuddyAction.hug => BuddyMood.empathetic,
    _ => BuddyMood.happy,
  };

  const shots = <BuddyAction, List<double>>{
    BuddyAction.eat: [0.4, 1.3, 2.0, 2.7, 3.6],
    BuddyAction.drink: [0.2, 0.9, 1.6, 2.6],
    BuddyAction.celebrate: [0.15, 0.45, 0.8, 1.2],
    BuddyAction.poke: [0.1, 0.25],
    BuddyAction.wakeUp: [0.3, 1.1, 1.8],
    BuddyAction.yawn: [0.4, 0.9, 1.5],
    BuddyAction.wave: [0.18, 0.53, 1.0],
    BuddyAction.relief: [0.4, 0.9, 1.6],
    BuddyAction.hug: [0.3, 0.8, 1.4],
    BuddyAction.nodYes: [0.12, 0.27, 0.6],
    BuddyAction.think: [0.4, 0.9],
  };

  for (final MapEntry(key: a, value: times) in shots.entries) {
    for (final at in times) {
      testWidgets('${a.name} $at', (tester) async {
        final c = BuddyController(mood: from(a));
        run(c, 1.0);
        c.play(a);
        run(c, at);
        await shoot(tester, 'action_${a.name}_$at', c);
      });
    }
  }

  testWidgets('eat with a meal photo', (tester) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 160, 120),
      Paint()..color = AppTheme.primary,
    );
    canvas.drawCircle(
      const Offset(80, 60),
      34,
      Paint()..color = AppTheme.warning,
    );
    final image = recorder.endRecording().toImageSync(160, 120);
    addTearDown(image.dispose);
    final c = BuddyController();
    run(c, 1.0);
    c.play(BuddyAction.eat, food: image);
    run(c, 0.4);
    await shoot(tester, 'action_eat_photo_0.4', c);
  });

  testWidgets('reduced motion eat', (tester) async {
    final c = BuddyController()..reducedMotion = true;
    run(c, 1.0);
    c.play(BuddyAction.eat);
    run(c, 2.0);
    await shoot(tester, 'reduced_eat_2.0', c);
  });
}
