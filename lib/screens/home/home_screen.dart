import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final bgAsset = isTablet ? 'assets/modeipad.svg' : 'assets/modeiphone.svg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Baggrund – iPad eller iPhone design
          Positioned.fill(
            child: SvgPicture.asset(
              bgAsset,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final designWidth = isTablet ? 450.0 : 360.0;
                final designHeight = isTablet ? 900.0 : 750.0;
                final textSize = isTablet ? 18.0 : 16.0;

                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: designWidth,
                      height: designHeight,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const Spacer(),
                          // To knapper nederst – uden ikoner
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ModeButton(
                                    title: 'Admin',
                                    onTap: () => context.go('/admin'),
                                    textSize: textSize,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _ModeButton(
                                    title: 'Barn',
                                    onTap: () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      final kidId = prefs.getString('kidId');
                                      final kidStayLoggedIn = prefs.getBool('kidStayLoggedIn') ?? true;
                                      if (!context.mounted) return;
                                      if (kidId != null && kidStayLoggedIn) {
                                        context.go('/kid/today/$kidId');
                                      } else {
                                        context.go('/kid/select');
                                      }
                                    },
                                    textSize: textSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('kidId');
                              await prefs.remove('kidStayLoggedIn');
                              await context.read<AuthProvider>().signOut();
                              if (context.mounted) context.go('/auth');
                            },
                            child: const Text(
                              'Log ud',
                              style: TextStyle(
                                color: Color(0xFFE8DCC8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final double textSize;

  const _ModeButton({
    required this.title,
    required this.onTap,
    required this.textSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF8B7355).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4A853), width: 1),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE8DCC8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
