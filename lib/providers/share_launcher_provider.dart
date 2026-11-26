import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet with a text. [origin] is the screen rect of
/// the button that was tapped: iPad anchors its share popover there and
/// fails to open without it. A provider so tests can replace the platform
/// call.
typedef ShareLauncher = Future<void> Function(String text, Rect origin);

final shareLauncherProvider = Provider<ShareLauncher>(
  (ref) =>
      (text, origin) => SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      ),
);
