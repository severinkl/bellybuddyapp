import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/app_foreground_provider.dart';

import '../helpers/app_lifecycle.dart';

void main() {
  // The provider's AppLifecycleListener needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A container whose returns to the foreground are counted.
  (ProviderContainer, List<int>) makeContainer() {
    final c = ProviderContainer.test();
    final heard = <int>[];
    c.listen(appForegroundProvider, (_, n) => heard.add(n));
    return (c, heard);
  }

  test('each return from the background is heard once', () {
    final (_, heard) = makeContainer();

    returnFromBackground();
    returnFromBackground();

    expect(heard, [1, 2]);
  });

  test('an inactive blip (Control Center, Face ID) is no return', () {
    final (_, heard) = makeContainer();

    inactiveBlip();

    expect(heard, isEmpty);
  });

  test('disposed: returns are ignored', () {
    final (c, heard) = makeContainer();
    c.dispose();

    returnFromBackground();

    expect(heard, isEmpty);
  });
}
