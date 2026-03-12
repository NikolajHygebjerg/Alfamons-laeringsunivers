import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indstillinger'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: Supabase.instance.client.from('settings').select('key,value'),
        builder: (ctx, snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ListTile(
                title: Text('Alfamon-oplåsningskode'),
                subtitle: Text(
                  '4-cifret kode til at låse ABC-bogstaver op. Konfigureres i Supabase.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
