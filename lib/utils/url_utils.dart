import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logger.dart';

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
    _log.error('Opening $url failed', e, st);
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
  return opened;
}
