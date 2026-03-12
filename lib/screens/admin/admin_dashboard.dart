import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A1A0D), Color(0xFFE85A4A)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _AdminTile(
              icon: Icons.child_care,
              title: 'Børn',
              subtitle: 'Administrer børn og PIN-koder',
              onTap: () => context.push('/admin/kids'),
            ),
            _AdminTile(
              icon: Icons.task_alt,
              title: 'Opgaver',
              subtitle: 'Opret og tildel opgaver',
              onTap: () => context.push('/admin/tasks'),
            ),
            _AdminTile(
              icon: Icons.face,
              title: 'Avatars',
              subtitle: 'Administrer Alfamon-avatars',
              onTap: () => context.push('/admin/avatars'),
            ),
            _AdminTile(
              icon: Icons.settings,
              title: 'Indstillinger',
              subtitle: 'App-indstillinger',
              onTap: () => context.push('/admin/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF9C433).withOpacity(0.9),
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
