import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../screens/account_screens.dart';
import '../screens/app_shell.dart';
import '../screens/auth_callback_screen.dart';
import '../screens/auth_screens.dart';
import '../screens/checkout_screen.dart';
import '../screens/welcome_screen.dart';
import 'auth_refresh.dart';
import '../providers/app_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final AppConfig config = ref.watch(appConfigProvider);
  final AuthRefresh refresh = AuthRefresh(client);
  ref.onDispose(refresh.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final bool signedIn = client.auth.currentSession != null;
      final String path = state.uri.path;
      const Set<String> authPaths = <String>{
        '/',
        '/login',
        '/signup',
        '/reset-password',
        '/email-sent',
      };
      if (!signedIn && (path == '/app' || path == '/checkout')) return '/';
      if (path == '/auth/callback' && signedIn) return '/app';
      if (signedIn && authPaths.contains(path)) {
        final String query = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/app$query';
      }
      if (config.storeBuild && path == '/checkout') return '/app';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/email-sent',
        builder: (context, state) => const EmailSentScreen(),
      ),
      GoRoute(path: '/app', builder: (context, state) => const AppShell()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! CheckoutScreenArgs) {
            return const InvalidCheckoutScreen();
          }
          return CheckoutScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
