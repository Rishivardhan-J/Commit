import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/app_store.dart';
import '../../features/commit/commit_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/roadmap/roadmap_screen.dart';
import '../../features/home/shell.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/skills/skills_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/vault/vault_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(appProvider).onboarded;
  final refresh = ValueNotifier(0);
  ref.listen(appProvider.select((s) => s.onboarded), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: onboarded ? '/home' : '/onboarding',
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(appProvider).onboarded;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!done && !atOnboarding) return '/onboarding';
      if (done && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/commit',
        pageBuilder: (_, _) => const MaterialPage(fullscreenDialog: true, child: CommitScreen()),
      ),
      GoRoute(path: '/focus', builder: (_, _) => const FocusScreen()),
      GoRoute(path: '/roadmaps', builder: (_, _) => const RoadmapScreen()),
      GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/tasks', builder: (_, _) => const TasksScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/vault', builder: (_, _) => const VaultScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/skills', builder: (_, _) => const SkillsScreen())]),
        ],
      ),
    ],
  );
});
