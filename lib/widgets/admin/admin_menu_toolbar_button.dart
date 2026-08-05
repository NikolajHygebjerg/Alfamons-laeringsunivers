import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Går til børnevalg (`/kid/select`) i mobil-/desktop-app; på web (kun admin) til `/admin`.
class AdminMenuToolbarButton extends StatelessWidget {
  const AdminMenuToolbarButton({
    super.key,
    this.lightOnDark = true,
  });

  /// `true` når AppBar har mørk brun baggrund og hvid [foregroundColor].
  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    final c = lightOnDark ? Colors.white : null;
    return TextButton.icon(
      onPressed: () {
        if (kIsWeb) {
          context.go('/admin');
        } else {
          context.go('/kid/select');
        }
      },
      icon: Icon(Icons.home_outlined, size: 20, color: c),
      label: Text('Menu', style: TextStyle(color: c)),
    );
  }
}

/// Logger ud (Supabase) og sender til login. Samme stil som [AdminMenuToolbarButton].
class AdminLogoutToolbarButton extends StatelessWidget {
  const AdminLogoutToolbarButton({
    super.key,
    this.lightOnDark = true,
  });

  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    final c = lightOnDark ? Colors.white : null;
    return TextButton.icon(
      onPressed: () async {
        await context.read<AuthProvider>().signOut();
        if (context.mounted) {
          context.go('/auth');
        }
      },
      icon: Icon(Icons.logout, size: 20, color: c),
      label: Text('Log ud', style: TextStyle(color: c)),
    );
  }
}

/// [AdminMenuToolbarButton] + [AdminLogoutToolbarButton] i én række (typisk i AppBar).
class AdminAppBarMenuAndLogout extends StatelessWidget {
  const AdminAppBarMenuAndLogout({
    super.key,
    this.lightOnDark = true,
  });

  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminMenuToolbarButton(lightOnDark: lightOnDark),
        AdminLogoutToolbarButton(lightOnDark: lightOnDark),
      ],
    );
  }
}
