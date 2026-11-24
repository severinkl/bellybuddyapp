/// [items] as German copy: „A", „A und B", „A, B und C"; empty for none.
String joinGerman(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';

/// Lower-case keys in German dictionary order (DIN 5007-1): ä, ö, ü as a,
/// o, u and ß as ss, so „äpfel" sorts with the a's, not after „zwiebel".
/// Keys equal that way (e.g. „masse", „maße") fall back to their code
/// units, so the order stays total and the same whatever the input order.
int germanOrder(String keyA, String keyB) {
  final folded = _foldUmlauts(keyA).compareTo(_foldUmlauts(keyB));
  return folded != 0 ? folded : keyA.compareTo(keyB);
}

String _foldUmlauts(String key) => key
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss');
