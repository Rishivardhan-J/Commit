import 'package:commit/core/utils/day_key.dart';
import 'package:commit/data/models.dart';
import 'package:commit/engine/autocomplete_engine.dart';
import 'package:commit/engine/streak_engine.dart';
import 'package:commit/engine/suggestion_engine.dart';
import 'package:commit/engine/xp_engine.dart';
import 'package:commit/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

AppState withDays(List<String> days) =>
    AppState(commits: [for (final d in days) DayCommit(day: d, tasks: 1)]);

void main() {
  hotfixTests();
  reminderTests();
  group('levels', () {
    test('level thresholds', () {
      expect(levelFor(0).level, 1);
      expect(levelFor(49).level, 1);
      expect(levelFor(50).level, 2);
      expect(levelFor(200).level, 3);
      expect(levelFor(60).remaining, 140);
    });
    test('critical days are deterministic and roughly 15%', () {
      expect(isCriticalDay('2026-11-09'), isCriticalDay('2026-11-09'));
      var n = 0;
      for (var i = 0; i < 1000; i++) {
        if (isCriticalDay(addDays('2024-01-01', i))) n++;
      }
      expect(n, inInclusiveRange(80, 230));
    });
    test('no bonus without tasks', () => expect(commitBonus('2026-11-09', 0), 0));
  });

  group('streak', () {
    test('counts consecutive days, still alive before committing today', () {
      final s = withDays(['2026-11-06', '2026-11-07', '2026-11-08']);
      final info = computeStreak(s, '2026-11-09');
      expect(info.current, 3);
      expect(info.atRisk, isTrue);
      expect(info.committedToday, isFalse);
    });
    test('breaks after a missed day', () {
      final s = withDays(['2026-11-05', '2026-11-06']);
      expect(computeStreak(s, '2026-11-09').current, 0);
    });
    test('rest days keep the chain', () {
      final s = withDays(['2026-11-07', '2026-11-09']).copyWith(restDays: ['2026-11-08']);
      expect(computeStreak(s, '2026-11-09').current, 3);
    });
    test('stash auto-applies for a single missed day', () {
      final s = withDays(['2026-11-06', '2026-11-07']).copyWith(stash: 1);
      final r = applyStashIfNeeded(s, '2026-11-09');
      expect(r.stash, 0);
      expect(computeStreak(r, '2026-11-09').current, 3);
      expect(r.commits.last.frozen, isTrue);
    });
    test('stash does not invent a streak from nothing', () {
      final r = applyStashIfNeeded(AppState(stash: 1), '2026-11-09');
      expect(r.stash, 1);
    });
    test('stash awarded each 7-day milestone, max 2', () {
      var s = awardStash(const AppState(), 7);
      expect(s.stash, 1);
      s = awardStash(s, 8);
      expect(s.stash, 1);
      s = awardStash(s, 14);
      s = awardStash(s, 21);
      expect(s.stash, 2);
    });
    test('day math across DST', () {
      expect(addDays('2026-03-07', 1), '2026-03-08');
      expect(daysBetween('2026-10-31', '2026-11-02'), 2);
    });
  });

  group('auto-complete', () {
    test('ticks a staged task once the metric hits target', () {
      final snap = PlatformSnapshot(
          platform: 'leetcode', username: 'u', fetchedAt: DateTime(2026, 11, 9), activity: {'2026-11-09': 2});
      final s = AppState(
        snapshots: {'leetcode': snap},
        tasks: const [
          Task(id: 'a', title: 'Solve 2', type: TaskType.dsa, skill: 'Arrays', stagedFor: '2026-11-09', rule: AutoRule('lc.solved', 2)),
          Task(id: 'b', title: 'Solve 3', type: TaskType.dsa, skill: 'Arrays', stagedFor: '2026-11-09', rule: AutoRule('lc.solved', 3)),
        ],
      );
      expect(satisfiedTasks(s, '2026-11-09').map((t) => t.id), ['a']);
    });
  });

  group('suggestions', () {
    test('suggests the weakest core topic', () {
      final snap = PlatformSnapshot(
          platform: 'leetcode', username: 'u', fetchedAt: DateTime(2026, 11, 9),
          breakdown: {'Array': 60, 'Graph': 4, 'Dynamic Programming': 40, 'Tree': 30, 'Binary Search': 20, 'Hash Table': 50, 'Linked List': 25, 'Backtracking': 15});
      final s = AppState(snapshots: {'leetcode': snap}, focusSkills: ['Arrays']);
      final r = buildSuggestions(s, '2026-11-09');
      expect(r.first.skill, 'Graphs');
      expect(r.first.rule?.metric, 'lc.solved');
    });
    test('dismissed suggestions disappear for the day', () {
      final s = const AppState(focusSkills: ['Flutter']);
      final first = buildSuggestions(s, '2026-11-09').first;
      final s2 = s.copyWith(dismissedSuggestions: ['2026-11-09|${first.title}']);
      expect(buildSuggestions(s2, '2026-11-09').any((x) => x.title == first.title), isFalse);
    });
  });

  test('state survives JSON round-trip', () {
    final s = AppState(
      name: 'Ada',
      tasks: const [Task(id: '1', title: 't', type: TaskType.learning, skill: 'Flutter', rule: AutoRule('gh.commits', 1))],
      commits: const [DayCommit(day: '2026-11-09', xp: 30, bonus: 25, tasks: 1)],
      skillXp: const {'Flutter': 10},
      wallet: const [WalletItem(id: 'w', kind: WalletKind.idea, title: 'x', tags: ['a'])],
    );
    final r = AppState.decode(s.encode());
    expect(r.name, 'Ada');
    expect(r.tasks.single.rule?.target, 1);
    expect(r.totalXp, 10 + 25);
    expect(r.wallet.single.tags, ['a']);
  });
}

void hotfixTests() {
  group('hotfix', () {
    test('available after exactly one missed day with no stash', () {
      final s = withDays(['2026-11-06', '2026-11-07']);
      expect(hotfixAvailable(s, '2026-11-09'), isTrue);
      expect(hotfixAvailable(s.copyWith(stash: 1), '2026-11-09'), isFalse);
      expect(hotfixAvailable(withDays(['2026-11-04']), '2026-11-09'), isFalse);
    });
    test('applying repairs the chain', () {
      final s = applyHotfix(withDays(['2026-11-06', '2026-11-07']), '2026-11-09')
          .copyWith(commits: [
        ...applyHotfix(withDays(['2026-11-06', '2026-11-07']), '2026-11-09').commits,
        const DayCommit(day: '2026-11-09', tasks: 2),
      ]);
      expect(computeStreak(s, '2026-11-09').current, 4);
    });
  });
}

void reminderTests() {
  test('reminder is today when still ahead and uncommitted, else tomorrow', () {
    final now = DateTime(2026, 11, 9, 18);
    expect(NotificationService.nextReminder(now, 21, committedToday: false), DateTime(2026, 11, 9, 21));
    expect(NotificationService.nextReminder(now, 21, committedToday: true), DateTime(2026, 11, 10, 21));
    expect(NotificationService.nextReminder(DateTime(2026, 11, 9, 22), 21, committedToday: false), DateTime(2026, 11, 10, 21));
  });
}
