import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/app_store.dart';
import '../../features/commit/commit_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/roadmap/roadmap_screen.dart';
import '../../features/home/shell.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/skills/skills_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/vault/vault_screen.dart';

/// Shared transition for pushed pages: short fade with a slight slide-in.
CustomTransitionPage<void> slideFadePage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

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
      GoRoute(path: '/focus', pageBuilder: (_, st) => slideFadePage(st, const FocusScreen())),
      GoRoute(path: '/friends', pageBuilder: (_, st) => slideFadePage(st, const FriendsScreen())),
      GoRoute(path: '/roadmaps', pageBuilder: (_, st) => slideFadePage(st, const RoadmapScreen())),
      GoRoute(path: '/stats', pageBuilder: (_, st) => slideFadePage(st, const StatsScreen())),
      GoRoute(path: '/settings', pageBuilder: (_, st) => slideFadePage(st, const SettingsScreen())),
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) =>
            AnimatedBranchContainer(currentIndex: shell.currentIndex, children: children),
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
