import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_kids_screen.dart';
import 'screens/admin/admin_tasks_screen.dart';
import 'screens/admin/admin_avatars_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/kid/kid_select_screen.dart';
import 'screens/kid/kid_today_screen.dart';
import 'screens/kid/kid_week_screen.dart';
import 'screens/kid/kid_library_screen.dart';
import 'screens/kid/kid_achievements_screen.dart';
import 'screens/kid/kid_spil_screen.dart';
import 'screens/kid/kid_test_cards_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  final authProvider = AuthProvider();
  runApp(AlfamonApp(authProvider: authProvider));
}

class AlfamonApp extends StatelessWidget {
  const AlfamonApp({super.key, required this.authProvider});
  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp.router(
        title: 'Alfamon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF9C433)),
          useMaterial3: true,
        ),
        routerConfig: _router(authProvider),
      ),
    );
  }
}

GoRouter _router(AuthProvider authProvider) => GoRouter(
  initialLocation: '/',
  refreshListenable: authProvider,
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final isAuth = auth.isAuthenticated;
    final isAuthRoute = state.matchedLocation == '/auth';

    if (!isAuth && !isAuthRoute) return '/auth';
    if (isAuth && isAuthRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminDashboard(),
      routes: [
        GoRoute(
          path: 'kids',
          builder: (_, __) => const AdminKidsScreen(),
        ),
        GoRoute(
          path: 'tasks',
          builder: (_, __) => const AdminTasksScreen(),
        ),
        GoRoute(
          path: 'avatars',
          builder: (_, __) => const AdminAvatarsScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (_, __) => const AdminSettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/kid/select',
      builder: (_, __) => const KidSelectScreen(),
    ),
    GoRoute(
      path: '/kid/today/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidTodayScreen(kidId: kidId);
      },
    ),
    GoRoute(
      path: '/kid/week/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidWeekScreen(kidId: kidId);
      },
    ),
    GoRoute(
      path: '/kid/library/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidLibraryScreen(kidId: kidId);
      },
    ),
    GoRoute(
      path: '/kid/achievements/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidAchievementsScreen(kidId: kidId);
      },
    ),
    GoRoute(
      path: '/kid/spil/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidSpilScreen(kidId: kidId);
      },
    ),
    GoRoute(
      path: '/kid/test/:kidId',
      builder: (context, state) {
        final kidId = state.pathParameters['kidId']!;
        return KidTestCardsScreen(kidId: kidId);
      },
    ),
  ],
);
