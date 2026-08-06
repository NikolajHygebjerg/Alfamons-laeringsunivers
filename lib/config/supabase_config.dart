import 'package:flutter/foundation.dart' show kIsWeb;

import 'supabase_config_local.dart' as local;

/// Supabase configuration.
///
/// Anon key: `--dart-define=SUPABASE_ANON_KEY=…` har forrang, ellers
/// `supabase_config_local.dart` (gitignored — kopiér fra
/// [supabase_config_local_example.dart]).
class SupabaseConfig {
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String _defaultUrl =
      'https://bdsnfnwcnfnszgdqbapo.supabase.co';

  static String get url => _envUrl.isNotEmpty ? _envUrl : _defaultUrl;

  static String get anonKey =>
      _envAnonKey.isNotEmpty ? _envAnonKey : local.supabaseAnonKey;

  /// Deeplink efter email-bekræftelse / nulstilling af kodeord (iOS/Android).
  /// Skal tilføjes under Authentication → URL Configuration → Redirect URLs i Supabase
  /// (sammen med evt. Flutter web-URL). Må ikke kun være www.alfamon.dk hvis det er den gamle app.
  static const String authRedirectNative = 'alfamon://login-callback';

  /// redirect_to i bekræftelses- og reset-mail. På web: nuværende origin (hvidlist samme URL i Supabase).
  static String get authEmailRedirectTo =>
      kIsWeb ? Uri.base.origin : authRedirectNative;
}
