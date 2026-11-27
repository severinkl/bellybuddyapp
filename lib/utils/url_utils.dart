import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logger.dart';

/// The iOS Settings page of the app.
const appSettingsUrl = 'app-settings:';

/// Android's way to the app's system settings (`MainActivity`):
/// `openAppSettings` (the app's details page) and `openNotificationSettings`.
const appSettingsChannel = MethodChannel('belly_buddy/app_settings');

/// Whether [url] is a web link: it starts with http:// or https://.
bool isHttpUrl(String url) =>
    url.startsWith('https://') || url.startsWith('http://');

/// Opens [url] the way `url_launcher`'s `launchUrl` does. Screens that open
/// links take one (default `launchUrl`), so tests can record the launches.
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});

const _log = AppLogger('ExternalUrl');

/// Opens [url] with [open] — in an external app (the browser) unless [mode]
/// says otherwise — and completes with whether it opened. When that
/// fails — the launch throws or reports false — shows [failureMessage] in a
/// SnackBar on [context]'s messenger, if there is one.
Future<bool> openExternalUrl(
  BuildContext context,
  String url, {
  required String failureMessage,
  UrlOpener open = launchUrl,
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await open(Uri.parse(url), mode: mode);
  } catch (e, st) {
    // The failure kind only: the url can hold what the user scanned.
    _log.error('Opening a link failed (${e.runtimeType})', null, st);
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
  return opened;
}

const _settingsFailed = 'Die Einstellungen konnten nicht geöffnet werden.';

/// Opens the app's page in the system settings — on iOS `app-settings:`
/// with [open], on Android the app's details page through
/// [appSettingsChannel] — and completes with whether it opened; when that
/// fails, shows a SnackBar on [context]'s messenger. [platform] defaults to
/// [defaultTargetPlatform].
Future<bool> openAppSettings(
  BuildContext context, {
  UrlOpener? open,
  TargetPlatform? platform,
}) async {
  if ((platform ?? defaultTargetPlatform) != TargetPlatform.android) {
    return openExternalUrl(
      context,
      appSettingsUrl,
      failureMessage: _settingsFailed,
      open: open ?? launchUrl,
    );
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened =
        await appSettingsChannel.invokeMethod<bool>('openAppSettings') ?? false;
  } catch (e, st) {
    _log.error('Opening the app settings failed (${e.runtimeType})', null, st);
  }
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text(_settingsFailed)));
  }
  return opened;
}
