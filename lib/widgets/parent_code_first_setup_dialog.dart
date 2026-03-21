import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/parent_code_service.dart';

/// Vises når der ikke er sat forældrekode endnu (typisk første login som forælder).
class ParentCodeFirstSetupDialog extends StatefulWidget {
  const ParentCodeFirstSetupDialog({super.key});

  /// Vis dialog hvis nødvendigt. Undgår dobbelt-dialog (Home + Admin).
  static bool _showing = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_showing) return;
    if (!context.mounted) return;
    if (!await ParentCodeService.needsSetup()) return;
    if (!context.mounted) return;

    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const ParentCodeFirstSetupDialog(),
      );
    } finally {
      _showing = false;
    }
  }

  @override
  State<ParentCodeFirstSetupDialog> createState() => _ParentCodeFirstSetupDialogState();
}

class _ParentCodeFirstSetupDialogState extends State<ParentCodeFirstSetupDialog> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _c1.text.trim();
    final repeat = _c2.text.trim();
    setState(() => _error = null);

    if (!ParentCodeService.isValidFormat(code)) {
      setState(() => _error = 'Brug præcis 4 cifre (fx 1234).');
      return;
    }
    if (code != repeat) {
      setState(() => _error = 'Koderne matcher ikke. Prøv igen.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ParentCodeService.saveApprovalCode(code);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forældrekode er sat. Du kan ændre den senere under Indstillinger.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vælg forældrekode'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Som forælder skal du bruge denne 4-cifrede kode når et barn færdiggør en opgave, '
              'ved godkendelse af opgaver og ved point for læsning. Vælg en kode I kan huske.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _c1,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              decoration: const InputDecoration(
                labelText: 'Forældrekode',
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c2,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              decoration: const InputDecoration(
                labelText: 'Gentag kode',
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _signOut,
          child: const Text('Log ud'),
        ),
        FilledButton(
          onPressed: _saving || _c1.text.length != 4 || _c2.text.length != 4 ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5A1A0D)),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Gem og fortsæt'),
        ),
      ],
    );
  }
}
