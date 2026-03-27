/// Parser til admin-input, fx `1+1=2` eller `12 - 5 = 7`.
class MathTaskParseResult {
  const MathTaskParseResult({required this.prompt, required this.answer});

  final String prompt;
  final String answer;
}

MathTaskParseResult? parseMathTaskLine(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final idx = t.indexOf('=');
  if (idx <= 0 || idx >= t.length - 1) return null;
  final prompt = t.substring(0, idx).trim();
  final answer = t.substring(idx + 1).trim();
  if (prompt.isEmpty || answer.isEmpty) return null;
  return MathTaskParseResult(prompt: prompt, answer: answer);
}

String _normSpaces(String s) => s.trim().replaceAll(RegExp(r'\s+'), '');

/// Sammenlign barnets svar med forventet (tillader mellemrum; numerisk hvis begge parser).
bool mathAnswersMatch(String expected, String given) {
  final a = _normSpaces(expected).replaceAll(',', '.');
  final b = _normSpaces(given).replaceAll(',', '.');
  if (a == b) return true;
  final na = num.tryParse(a);
  final nb = num.tryParse(b);
  if (na != null && nb != null) return na == nb;
  return false;
}
