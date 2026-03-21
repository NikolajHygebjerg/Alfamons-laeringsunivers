import 'package:supabase_flutter/supabase_flutter.dart';

/// Forældrekode gemmes i `settings` med nøglen `approval_code`.
class ParentCodeService {
  ParentCodeService._();

  static Future<String?> fetchApprovalCode() async {
    final res = await Supabase.instance.client
        .from('settings')
        .select('value')
        .eq('key', 'approval_code')
        .maybeSingle();
    final v = res?['value'];
    if (v == null) return null;
    return v.toString().trim();
  }

  /// Tom eller manglende række → skal sættes ved første login.
  static Future<bool> needsSetup() async {
    final c = await fetchApprovalCode();
    return c == null || c.isEmpty;
  }

  static Future<void> saveApprovalCode(String code) async {
    await Supabase.instance.client.from('settings').upsert(
      {'key': 'approval_code', 'value': code.trim()},
      onConflict: 'key',
    );
  }

  /// Kræver præcis 4 cifre (samme som ved opgave-godkendelse).
  static bool isValidFormat(String code) {
    final t = code.trim();
    return t.length == 4 && RegExp(r'^\d{4}$').hasMatch(t);
  }
}
