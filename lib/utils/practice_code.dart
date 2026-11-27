import '../config/constants.dart';

/// A practice code as core's `normalize_code` checks it.
final _code = RegExp(r'[A-Z]{2,6}-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{3}');

/// The host of Belly Buddy Connect, which a practice QR code links to.
final _connectHost = Uri.parse(AppConstants.connectUrl).host;

/// The ASCII characters a typed code may carry: space, tab, CR, LF, `-`.
final _stripped = RegExp('[ \t\r\n-]');

/// A typed practice code in canonical form (`BERGER-7K2`), or null if it
/// cannot be one. Core's `normalize_code` rules one to one (ASCII-exact):
/// anything outside ASCII fails; space, tab, CR, LF and `-` are dropped;
/// a-z upper-cased; a `-` goes before the last three characters; the result
/// must match the whole pattern.
String? normalizePracticeCode(String raw) {
  if (raw.codeUnits.any((c) => c > 127)) return null;
  final compact = raw.replaceAll(_stripped, '').toUpperCase();
  if (compact.length < 3) return null;
  final cut = compact.length - 3;
  final code = '${compact.substring(0, cut)}-${compact.substring(cut)}';
  final match = _code.matchAsPrefix(code);
  return match != null && match.end == code.length ? code : null;
}

/// The practice code of a scanned QR: `https://<Connect host>/c/<code>`
/// (https, that host, no port, query or fragment) or a bare code, normalized;
/// null for anything else.
String? practiceCodeFromScan(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return normalizePracticeCode(text);
  final segments = uri.pathSegments;
  if (uri.scheme != 'https' ||
      uri.host != _connectHost ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      segments.length != 2 ||
      segments.first != 'c') {
    return null;
  }
  return normalizePracticeCode(segments.last);
}
