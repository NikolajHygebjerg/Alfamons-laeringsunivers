import 'package:supabase_flutter/supabase_flutter.dart';

/// Læser barnets guldmønter i kisten (`kids.gold_coins`).
class KidGoldService {
  KidGoldService._();

  static final _client = Supabase.instance.client;

  static Future<int> fetchGoldCoins(String kidId) async {
    final r = await _client
        .from('kids')
        .select('gold_coins')
        .eq('id', kidId)
        .maybeSingle();
    return (r?['gold_coins'] as num?)?.toInt() ?? 0;
  }
}
