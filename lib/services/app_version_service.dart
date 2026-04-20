import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';

/// Wraps package_info_plus + url_launcher for the upgrade-gate flow.
class AppVersionService {
  AppVersionService();

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<String> packageName() async {
    final info = await PackageInfo.fromPlatform();
    return info.packageName;
  }

  /// Opens the platform-appropriate store page for the app.
  Future<void> openStore() async {
    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConstants.appStoreUrl()
        : AppConstants.playStoreUrl(await packageName());
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
