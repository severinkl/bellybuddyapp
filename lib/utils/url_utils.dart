import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logger.dart';

/// Returns true if [url] starts with http:// or https://.
bool isValidImageUrl(String url) =>
    url.startsWith('https://') || url.startsWith('http://');

/// Opens [url] the way `url_launcher`'s `launchUrl` does. Screens that open
/// links take one (default `launchUrl`), so tests can record the launches.
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});

const _log = AppLogger('ExternalUrl');

/// Opens [url] in an external app (the browser) with [open]. When that
/// fails — the launch throws or reports false — shows [failureMessage] in a
/// SnackBar on [context]'s messenger, if there is one.
Future<void> openExternalUrl(
  BuildContext context,
  String url, {
  required String failureMessage,
  UrlOpener open = launchUrl,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await open(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e, st) {
    _log.error('Opening $url failed', e, st);
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
