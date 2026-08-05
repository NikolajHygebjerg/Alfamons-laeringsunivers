/// Udstillingsnavn for en Alfamon (ensretter gamle stavemåder fra database).
String alfamonDisplayName(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return t;
  if (t.toLowerCase() == 'zebra') return 'Zetbra';
  return t;
}
