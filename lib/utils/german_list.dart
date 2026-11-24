/// [items] as German copy: „A", „A und B", „A, B und C"; empty for none.
String joinGerman(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';
