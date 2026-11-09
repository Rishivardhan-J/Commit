import 'package:commit/data/models.dart';
import 'package:commit/engine/challenge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekStart is Monday', () {
    expect(weekStart('2026-11-09'), '2026-11-09'); // Monday
    expect(weekStart('2026-11-15'), '2026-11-09'); // Sunday
  });

  test('progress counts only this week and claims once', () {
    final s = AppState(
      onboarded: true,
      commits: const [
        DayCommit(day: '2026-11-02', tasks: 1, xp: 10),
        DayCommit(day: '2026-11-09', tasks: 1, xp: 10),
        DayCommit(day: '2026-11-10', tasks: 1, xp: 10),
      ],
      focusByDay: const {'2026-11-10': 100, '2026-11-01': 500},
    );
    final cs = weeklyChallenges(s, '2026-11-11');
    expect(cs.firstWhere((c) => c.id == 'days').progress, 2);
    expect(cs.firstWhere((c) => c.id == 'focus').progress, 100);
    final done = claimable(s.copyWith(focusByDay: {'2026-11-10': 999}), '2026-11-11');
    expect(done.map((c) => c.id), ['focus']);
    final claimed = s.copyWith(focusByDay: {'2026-11-10': 999}, claimedChallenges: [claimKey('2026-11-11', 'focus')]);
    expect(claimable(claimed, '2026-11-11'), isEmpty);
  });
}
