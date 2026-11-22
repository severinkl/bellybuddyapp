import 'package:belly_buddy/services/app_version_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Belly Buddy',
      packageName: 'com.bellybuddy.belly_buddy',
      version: '1.4.2',
      buildNumber: '17',
      buildSignature: '',
    );
  });

  group('AppVersionService', () {
    test('currentVersion returns the semver portion', () async {
      final v = await AppVersionService().currentVersion();
      expect(v, '1.4.2');
    });

    test('packageName returns the Android package identifier', () async {
      final p = await AppVersionService().packageName();
      expect(p, 'com.bellybuddy.belly_buddy');
    });
  });
}
