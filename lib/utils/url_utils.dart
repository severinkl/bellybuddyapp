import 'package:url_launcher/url_launcher.dart';

/// Returns true if [url] starts with http:// or https://.
bool isValidImageUrl(String url) =>
    url.startsWith('https://') || url.startsWith('http://');

/// Opens [url] the way `url_launcher`'s `launchUrl` does. Screens that open
/// links take one (default `launchUrl`), so tests can record the launches.
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});
