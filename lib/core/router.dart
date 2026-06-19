import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/portal/screens/portal_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) {
        return auth.role == 'client' ? '/portal' : '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, st) => const DashboardScreen()),
      GoRoute(path: '/portal', builder: (ctx, st) => const PortalScreen()),
    ],
  );
});
