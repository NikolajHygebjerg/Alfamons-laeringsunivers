import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/parent_code_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadApprovalCode();
  }

  Future<void> _loadApprovalCode() async {
    final existing = await ParentCodeService.fetchApprovalCode();
    if (mounted) {
      _codeController.text = existing ?? '';
    }
  }

  Future<void> _saveApprovalCode() async {
    final code = _codeController.text.trim();
    if (!ParentCodeService.isValidFormat(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forældrekode skal være præcis 4 cifre')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ParentCodeService.saveApprovalCode(code);
      if (mounted) {
        setState(() => _loading = false);
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
                    '4 cifre – bruges når børn færdiggør opgaver, ved godkendelse og ved point for læsning. Du satte koden første gang du loggede ind; her kan du ændre den.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Forældrekode',
                      border: OutlineInputBorder(),
                      hintText: 'fx 1234',
                      counterText: '',
                    ),
                    obscureText: true,
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
