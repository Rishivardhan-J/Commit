import 'dart:math';

/// Level n starts at 50*(n-1)^2 XP: fast early levels (goal-gradient), slower later.
class LevelInfo {
  final int level;
  final int into; // xp into this level
  final int span; // xp needed for this level
  const LevelInfo(this.level, this.into, this.span);
  int get remaining => span - into;
  double get progress => span == 0 ? 0 : into / span;
}

LevelInfo levelFor(int xp, {int k = 50}) {
  final level = sqrt(xp / k).floor() + 1;
  final start = k * (level - 1) * (level - 1);
  final next = k * level * level;
  return LevelInfo(level, xp - start, next - start);
}

/// Skills level up a bit faster than the overall level.
LevelInfo skillLevelFor(int xp) => levelFor(xp, k: 20);

/// "you v2.4": major = level, minor = skills levelled beyond Lv1.
String versionString(int totalXp, Iterable<int> skillXps) {
  final major = levelFor(totalXp).level;
  final minor = skillXps.fold<int>(0, (a, x) => a + skillLevelFor(x).level - 1);
  return 'v$major.$minor';
}

/// ~15% of days get a "critical commit" (2x bonus). Deterministic per day so it
/// can't be re-rolled by reopening the ceremony.
bool isCriticalDay(String day) {
  var h = 17;
  for (final c in day.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % 100 < 15;
}

const int commitBonusBase = 20;

int commitBonus(String day, int taskCount) {
  if (taskCount == 0) return 0;
  final int base = commitBonusBase + 5 * min(taskCount, 5);
  return isCriticalDay(day) ? base * 2 : base;
}
