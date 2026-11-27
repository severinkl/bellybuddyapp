import 'dart:ui' show SemanticsFlag;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/utils/reduced_motion.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';
import 'package:belly_buddy/widgets/common/bb_auth_banner.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';
import 'package:belly_buddy/widgets/common/bb_icon_tap.dart';
import 'package:belly_buddy/widgets/common/bb_selection_button.dart';
import 'package:belly_buddy/widgets/common/bb_settings_item.dart';
import 'package:belly_buddy/widgets/common/circle_icon_button.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:belly_buddy/widgets/common/tap_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets(
    'BbIconTap is a named button with a 48×48 hit area for an 16 px icon',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BbIconTap(
            icon: Icons.close,
            iconSize: AppConstants.iconSizeXs,
            semanticLabel: 'Foto entfernen',
            onTap: () => taps++,
          ),
        ),
      );

      final hit = tester.getRect(find.byType(BbIconTap));
      expect(hit.size.width, greaterThanOrEqualTo(AppConstants.minTapTarget));
      expect(hit.size.height, greaterThanOrEqualTo(AppConstants.minTapTarget));
      expect(AppConstants.minTapTarget, 48);
      expect(
        tester.getSize(find.byIcon(Icons.close)),
        const Size.square(AppConstants.iconSizeXs),
      );
      expect(
        tester.getSemantics(find.byType(BbIconTap)),
        isSemantics(
          label: 'Foto entfernen',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      // A tap near the corner (outside the 16 px icon) still counts.
      await tester.tapAt(hit.topLeft + const Offset(2, 2));
      expect(taps, 1);
      handle.dispose();
    },
  );

  testWidgets('BbIconTap without onTap is a disabled button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const BbIconTap(
          icon: Icons.close,
          semanticLabel: 'Foto entfernen',
          onTap: null,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BbIconTap)),
      isSemantics(
        label: 'Foto entfernen',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('TapTarget lifts a 20 px chip to 48 high without drawing more', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GestureDetector(
          onTap: () => taps++,
          child: const TapTarget(
            child: SizedBox(key: Key('chip'), width: 80, height: 20),
          ),
        ),
      ),
    );

    final target = tester.getRect(find.byType(TapTarget));
    expect(target.height, AppConstants.minTapTarget);
    expect(target.width, greaterThanOrEqualTo(AppConstants.minTapTarget));
    expect(tester.getSize(find.byKey(const Key('chip'))), const Size(80, 20));
    expect(tester.getCenter(find.byKey(const Key('chip'))), target.center);
    expect(
      find.descendant(
        of: find.byType(TapTarget),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox || w is ColoredBox || w is CustomPaint,
        ),
      ),
      findsNothing,
    );

    // The padded area above the chip is part of the hit area.
    await tester.tapAt(target.topCenter + const Offset(0, 2));
    expect(taps, 1);
  });

  testWidgets(
    'ReducedMotion.duration is zero with disableAnimations, unchanged without',
    (tester) async {
      const d = Duration(milliseconds: 300);
      Duration? reduced;
      Duration? normal;
      bool? reducedFlag;
      bool? normalFlag;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = ReducedMotion.duration(context, d);
              reducedFlag = ReducedMotion.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              normal = ReducedMotion.duration(context, d);
              normalFlag = ReducedMotion.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(reduced, Duration.zero);
      expect(reducedFlag, isTrue);
      expect(normal, d);
      expect(normalFlag, isFalse);
    },
  );

  testWidgets('ReducedMotion.shimmer shows no Shimmer with disableAnimations', (
    tester,
  ) async {
    Widget shimmer() => Builder(
      builder: (context) => ReducedMotion.shimmer(
        context,
        baseColor: Colors.black,
        highlightColor: Colors.white,
        child: const SizedBox(key: Key('placeholder'), width: 40, height: 40),
      ),
    );

    await tester.pumpWidget(_host(shimmer(), disableAnimations: true));
    expect(find.byType(Shimmer), findsNothing);
    expect(find.byKey(const Key('placeholder')), findsOneWidget);
    final box = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.byKey(const Key('placeholder')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color, Colors.black);

    await tester.pumpWidget(_host(shimmer()));
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets(
    'MascotImage without a label adds no semantics node; with one it is an image named so',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const MascotImage(assetPath: AppConstants.mascotHappy)),
      );
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);

      await tester.pumpWidget(
        _host(
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            semanticLabel: 'Belly Buddy lacht',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MascotImage)),
        isSemantics(label: 'Belly Buddy lacht', isImage: true),
      );
      handle.dispose();
    },
  );

  testWidgets('BbAuthBanner is a live region with its text', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const BbAuthBanner(text: 'E-Mail oder Passwort falsch.')),
    );

    expect(
      tester.getSemantics(find.byType(BbAuthBanner)),
      isSemantics(label: 'E-Mail oder Passwort falsch.', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('BbErrorState message is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const BbErrorState(message: 'Das hat nicht geklappt.')),
    );
    expect(
      tester.getSemantics(find.text('Das hat nicht geklappt.')),
      isSemantics(label: 'Das hat nicht geklappt.', isLiveRegion: true),
    );

    await tester.pumpWidget(_host(const BbLoadingState(message: 'Lädt …')));
    expect(
      tester.getSemantics(find.text('Lädt …')),
      isSemantics(label: 'Lädt …', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('a loading BbButton still reads „Speichern", value „lädt"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(BbButton(label: 'Speichern', isLoading: true, onPressed: () {})),
    );

    expect(
      tester.getSemantics(find.byType(BbButton)),
      isSemantics(
        label: 'Speichern',
        value: 'lädt',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'a BbSettingsItem is a button named by its title; no scale with disableAnimations',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BbSettingsItem(
            icon: Icons.person,
            title: 'Profil',
            subtitle: 'Name und Ziele',
            onTap: () => taps++,
          ),
          disableAnimations: true,
        ),
      );

      final row = tester.getSemantics(find.text('Profil'));
      expect(row.label, startsWith('Profil'));
      expect(row, isSemantics(isButton: true, hasTapAction: true));

      final before = tester.getRect(find.byType(BbCard));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BbCard)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(find.byType(BbCard)), before);
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    },
  );

  testWidgets('a BbSelectionButton is one selected button node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            BbSelectionButton(
              label: 'Vegan',
              isSelected: true,
              onPressed: () {},
            ),
            BbSelectionButton(
              label: 'Blähungen',
              isSelected: false,
              singleChoice: false,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('Vegan')),
      isSemantics(
        label: 'Vegan',
        isButton: true,
        hasTapAction: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Blähungen')),
      isSemantics(
        label: 'Blähungen',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('CircleIconButton is 48 × 48 by default', (tester) async {
    await tester.pumpWidget(
      _host(
        CircleIconButton(
          icon: Icons.close,
          semanticLabel: 'Schließen',
          onPressed: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CircleIconButton)),
      const Size.square(AppConstants.minTapTarget),
    );
    expect(AppConstants.minTapTarget, 48);
  });
}
