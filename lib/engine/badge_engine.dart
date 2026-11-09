import '../data/models.dart';
import 'streak_engine.dart';
import 'package:flutter/widgets.dart' show IconData;
import '../core/icons.dart';

class BadgeDef {
  final String id;
  final String name;
  final String hint;
  final IconData icon;
  final bool Function(AppState s, int streak) earned;
  const BadgeDef(this.id, this.name, this.hint, this.icon, this.earned);
}

final badgeDefs = <BadgeDef>[
  BadgeDef('first_commit', 'Initial commit', 'Commit your first day', AppIcons.plant,
      (s, _) => s.commits.any((c) => !c.frozen)),
  BadgeDef('streak7', 'Seven-day branch', 'Reach a 7-day streak', AppIcons.flame, (s, k) => k >= 7),
  BadgeDef('streak30', 'Long-running process', 'Reach a 30-day streak', AppIcons.rocketLaunch, (s, k) => k >= 30),
  BadgeDef('streak100', 'Uptime 100', 'Reach a 100-day streak', AppIcons.mountains, (s, k) => k >= 100),
  BadgeDef('crit', 'Critical commit', 'Land a 2× XP commit', AppIcons.lightning, (s, _) => s.commits.any((c) => c.critical)),
  BadgeDef('solved100', 'Century', 'Solve 100 LeetCode problems', AppIcons.sealCheck, (s, _) {
    final lc = s.snapshots['leetcode'];
    return lc != null && (lc.stats['solved'] ?? 0) >= 100;
  }),
  BadgeDef('ci', 'CI passed', 'Let platform activity auto-complete a task', AppIcons.checkCircle, (s, _) => s.tasks.any((t) => t.auto)),
  BadgeDef('hack', 'Hackathon hacker', 'Save your first hackathon', AppIcons.flagCheckered,
      (s, _) => s.wallet.any((w) => w.kind == WalletKind.hackathon)),
  BadgeDef('idea5', 'Idea machine', 'Capture 5 ideas', AppIcons.lightbulb,
      (s, _) => s.wallet.where((w) => w.kind == WalletKind.idea).length >= 5),
  BadgeDef('lvl5', 'Level 5', 'Reach overall level 5', AppIcons.star, (s, _) => s.totalXp >= 800),
  BadgeDef('night', 'Night owl', 'Commit the day after 11pm', AppIcons.moonStars, (s, _) => s.badges.contains('night')),
];

BadgeDef? badgeById(String id) {
  for (final b in badgeDefs) {
    if (b.id == id) return b;
  }
  return null;
}

/// Newly earned badge ids.
List<String> newBadges(AppState s, String today) {
  final streak = computeStreak(s, today).current;
  return [
    for (final b in badgeDefs)
      if (!s.badges.contains(b.id) && b.earned(s, streak)) b.id,
  ];
}
