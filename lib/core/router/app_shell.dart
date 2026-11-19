import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/profile.dart';
import '../../features/boards/application/boards_providers.dart';
import '../../features/boards/domain/board.dart';
import '../../features/premium/billing_service.dart';
import '../../features/share_intake/presentation/share_intake_listener.dart';
import '../../features/share_intake/share_intake_controller.dart';
import '../l10n/strings.dart';

/// Bottom navigation (Boards · Contacts · Liens) + app-wide side effects.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    // RevenueCat app user id = Supabase user id.
    ref.listen<AsyncValue<Profile?>>(profileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile != null && prev?.valueOrNull?.id != profile.id) {
        unawaited(ref.read(billingServiceProvider).identify(profile.id));
      }
    });

    // Keep the iOS share extension's board list fresh.
    ref.listen<AsyncValue<List<Board>>>(boardsProvider, (prev, next) {
      final boards = next.valueOrNull;
      if (boards != null) unawaited(syncBoardsToShareExtension(ref, boards));
    });

    return ShareIntakeListener(
      child: Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: s.navBoards,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: s.navContacts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.link_rounded),
              selectedIcon: const Icon(Icons.link_rounded),
              label: s.navLinks,
            ),
          ],
        ),
      ),
    );
  }
}
