/// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
/// Parses three-part semver (X.Y.Z). Build-number suffix (`+N`) and any
/// pre-release suffix (`-rc1`) are stripped before comparing. Missing
/// segments default to zero.
int compareSemver(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final cmp = pa[i].compareTo(pb[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

List<int> _parts(String v) {
  final core = v.split(RegExp(r'[+\-]')).first;
  final segments = core.split('.');
  return [_toInt(segments, 0), _toInt(segments, 1), _toInt(segments, 2)];
}

int _toInt(List<String> segs, int i) {
  if (i >= segs.length) return 0;
  return int.tryParse(segs[i]) ?? 0;
}
