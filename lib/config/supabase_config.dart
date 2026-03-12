import 'supabase_config_local.dart';

/// Supabase configuration.
/// Anon key kommer fra supabase_config_local.dart – rediger den fil med din key.
class SupabaseConfig {
  static const String url = 'https://bdsnfnwcnfnszgdqbapo.supabase.co';
  static String get anonKey => supabaseAnonKey;
}
