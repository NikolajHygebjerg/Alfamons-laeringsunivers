import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadApprovalCode();
  }

  Future<void> _loadApprovalCode() async {
    final res = await Supabase.instance.client
        .from('settings')
        .select('value')
        .eq('key', 'approval_code')
        .maybeSingle();
    if (mounted) {
      _codeController.text = (res?['value'] as String?) ?? '';
    }
  }

  Future<void> _saveApprovalCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indtast en forældrekode')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _saved = false;
    });
    try {
      await Supabase.instance.client.from('settings').upsert(
        {'key': 'approval_code', 'value': code},
        onConflict: 'key',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _saved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forældrekode gemt')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indstillinger'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFF9C433).withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forældrekode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '4-tegn kode som forældre skal taste ved færdiggørelse og godkendelse af opgaver. Gælder for alle børn.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Forældrekode',
                      border: OutlineInputBorder(),
                      hintText: 'fx 1234',
                    ),
                    obscureText: true,
                    onChanged: (_) => setState(() => _saved = false),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _saveApprovalCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A1A0D),
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Gem forældrekode'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            title: Text('Alfamon-oplåsningskode'),
            subtitle: Text(
              '4-cifret kode til at låse ABC-bogstaver op. Konfigureres i Supabase.',
            ),
          ),
        ],
      ),
    );
  }
}
