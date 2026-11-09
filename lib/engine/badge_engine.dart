import '../data/models.dart';
import 'streak_engine.dart';

class BadgeDef {
  final String id;
  final String name;
  final String hint;
  final String emoji;
  final bool Function(AppState s, int streak) earned;
  const BadgeDef(this.id, this.name, this.hint, this.emoji, this.earned);
}

final badgeDefs = <BadgeDef>[
  BadgeDef('first_commit', 'Initial commit', 'Commit your first day', '🌱',
      (s, _) => s.commits.any((c) => !c.frozen)),
  BadgeDef('streak7', 'Seven-day branch', 'Reach a 7-day streak', '🔥', (s, k) => k >= 7),
  BadgeDef('streak30', 'Long-running process', 'Reach a 30-day streak', '🚀', (s, k) => k >= 30),
  BadgeDef('streak100', 'Uptime 100', 'Reach a 100-day streak', '🏔️', (s, k) => k >= 100),
  BadgeDef('crit', 'Critical commit', 'Land a 2× XP commit', '⚡', (s, _) => s.commits.any((c) => c.critical)),
  BadgeDef('solved100', 'Century', 'Solve 100 LeetCode problems', '💯', (s, _) {
    final lc = s.snapshots['leetcode'];
    return lc != null && (lc.stats['solved'] ?? 0) >= 100;
  }),
  BadgeDef('ci', 'CI passed', 'Let platform activity auto-complete a task', '✅', (s, _) => s.tasks.any((t) => t.auto)),
  BadgeDef('hack', 'Hackathon hacker', 'Save your first hackathon', '🏁',
      (s, _) => s.wallet.any((w) => w.kind == WalletKind.hackathon)),
  BadgeDef('idea5', 'Idea machine', 'Capture 5 ideas', '💡',
      (s, _) => s.wallet.where((w) => w.kind == WalletKind.idea).length >= 5),
  BadgeDef('lvl5', 'Level 5', 'Reach overall level 5', '⭐', (s, _) => s.totalXp >= 800),
  BadgeDef('night', 'Night owl', 'Commit the day after 11pm', '🦉', (s, _) => s.badges.contains('night')),
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
