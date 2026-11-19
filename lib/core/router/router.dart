import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/setup_screen.dart';
import '../../features/boards/presentation/board_screen.dart';
import '../../features/boards/presentation/home_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/links/presentation/links_screen.dart';
import '../../features/premium/paywall_screen.dart';
import '../../features/settings/legal_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sharing/presentation/join_board_screen.dart';
import '../../features/sharing/presentation/shared_board_screen.dart';
import '../env.dart';
import '../providers.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final refresh = _AuthRefresh(Env.isConfigured ? Supabase.instance.client.auth.onAuthStateChange : null);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/boards',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(state, prefs),
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/boards'),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/onboarding', builder: (_, state) => OnboardingScreen(from: state.uri.queryParameters['from'])),
      GoRoute(path: '/auth', builder: (_, state) => AuthScreen(from: state.uri.queryParameters['from'])),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/boards',
              builder: (_, __) => const HomeScreen(),
              routes: [
                GoRoute(path: ':id', builder: (_, state) => BoardScreen(boardId: state.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/links', builder: (_, __) => const LinksScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/paywall',
        pageBuilder: (_, state) => MaterialPage(key: state.pageKey, fullscreenDialog: true, child: const PaywallScreen()),
      ),
      GoRoute(path: '/privacy', builder: (_, __) => const LegalScreen(kind: LegalKind.privacy)),
      GoRoute(path: '/terms', builder: (_, __) => const LegalScreen(kind: LegalKind.terms)),
      GoRoute(path: '/s/:token', builder: (_, state) => SharedBoardScreen(token: state.pathParameters['token']!)),
      GoRoute(path: '/join/:token', builder: (_, state) => JoinBoardScreen(token: state.pathParameters['token']!)),
    ],
  );
});

String? _redirect(GoRouterState state, SharedPreferences prefs) {
  final loc = state.matchedLocation;
  if (!Env.isConfigured) return loc == '/setup' ? null : '/setup';
  if (loc.startsWith('/s/') || loc == '/privacy' || loc == '/terms') return null; // public pages

  final loggedIn = Supabase.instance.client.auth.currentSession != null;
  final onboardingSeen = prefs.getBool(onboardingSeenKey) ?? false;
  final inAuthArea = loc == '/onboarding' || loc == '/auth';

  if (!loggedIn) {
    if (inAuthArea) return null;
    final target = onboardingSeen ? '/auth' : '/onboarding';
    final from = state.uri.toString();
    final keepFrom = from.startsWith('/join/') || from.startsWith('/boards/');
    return keepFrom ? '$target?from=${Uri.encodeComponent(from)}' : target;
  }

  if (inAuthArea || loc == '/setup') {
    final from = state.uri.queryParameters['from'];
    return (from != null && from.startsWith('/')) ? from : '/boards';
  }
  return null;
}

/// Re-runs the redirect on every auth change (sign in, sign out, token refresh).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState>? stream) {
    _sub = stream?.listen((_) => notifyListeners());
  }

  StreamSubscription<AuthState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧭', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/boards'), child: const Text('Keevy')),
          ],
        ),
      ),
    );
  }
}
