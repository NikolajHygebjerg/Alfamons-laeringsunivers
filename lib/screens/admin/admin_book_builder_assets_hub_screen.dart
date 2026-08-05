import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_role_provider.dart';
import '../../services/book_builder_gallery_service.dart';
import '../../widgets/admin/admin_menu_toolbar_button.dart';

/// Samlet indgang: bundt-billeder fra appen + upload til [book_builder_extra_images].
/// Tilknytning (assets) i DB er RLS-begrænset til [BookBuilderGalleryService.kAdminEmail].
class AdminBookBuilderAssetsHubScreen extends StatelessWidget {
  const AdminBookBuilderAssetsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<ProfileRoleProvider>().isAdmin;
    final email = Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
    final isGallery = email == BookBuilderGalleryService.kAdminEmail;

    if (!isAdmin) {
      return _scaffold(
        context,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Du har ikke adgang.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (!isGallery) {
      return _scaffold(
        context,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Billedtilknytning og denne side er for den konto, der er knyttet til '
              'bogbyggerens billedbank (værktøjsforfatteren).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return _scaffold(
      context,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Her styrer du, hvilke billeder børn kan bruge i bogbyggeren: '
            'dem der følger med appen (assets), tildelt pr. Alfamon, '
            'samt ekstra filer du uploader.',
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 24),
          _CardNav(
            icon: Icons.grid_view,
            title: 'Bundt-billeder → Alfamon',
            subtitle:
                'Se alle raster-billeder i appen (AssetManifest) og knyt hver sti '
                'til den Alfamon, den skal vælges under i bogbyggeren.',
            onTap: () => context.push('/admin/book-builder/billedbibliotek'),
          ),
          const SizedBox(height: 16),
          _CardNav(
            icon: Icons.cloud_upload,
            title: 'Upload nye billeder per Alfamon',
            subtitle:
                'Gemmer i skyen under bogen/bogbygger (ekstra lager). '
                'Børn får flere valg sammen med udviklings- og trace-bundter.',
            onTap: () => context.push('/admin/book-builder/alfamon-billeder'),
          ),
        ],
      ),
    );
  }

  Widget _scaffold(BuildContext context, {required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bogbygger – billedbank'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: const [AdminAppBarMenuAndLogout()],
      ),
      body: body,
    );
  }
}

class _CardNav extends StatelessWidget {
  const _CardNav({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF9C433).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF5A1A0D)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Åbn →',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5A1A0D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
