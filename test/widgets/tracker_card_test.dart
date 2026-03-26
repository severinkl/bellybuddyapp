import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:belly_buddy/widgets/common/tracker_card.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('TrackerCard', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: TrackerCard(
            svgPath: 'assets/images/icons/toilet-paper-3.svg',
            label: 'Stuhlgang',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Stuhlgang'), findsOneWidget);
    });

    testWidgets('renders Tracker subtitle text', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: TrackerCard(
            svgPath: 'assets/images/icons/toilet-paper-3.svg',
            label: 'Stimmung',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Tracker'), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWithProviders(
        Scaffold(
          body: TrackerCard(
            svgPath: 'assets/images/icons/toilet-paper-3.svg',
            label: 'Mahlzeit',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('Mahlzeit'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders SvgPicture widget', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: TrackerCard(
            svgPath: 'assets/images/icons/toilet-paper-3.svg',
            label: 'Test',
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
