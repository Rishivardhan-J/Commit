import 'package:commit/app.dart';
import 'package:commit/data/app_store.dart';
import 'package:commit/data/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  final clock = DateTime(2026, 11, 9, 20);

  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => clock),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('stage → complete → commit awards xp, streak and badge, once per day', () {
    final c = make();
    final n = c.read(appProvider.notifier);
    n.completeOnboarding(name: 'A', identity: 'Backend developer', skills: ['Graphs']);
    final t = n.addTask(title: 'BFS', type: TaskType.dsa, skill: 'Graphs', difficulty: 2);
    n.toggleDone(t.id);
    final r = n.commitDay('did bfs')!;
    expect(r.taskXp, 20);
    expect(r.streak, 1);
    final s = c.read(appProvider);
    expect(s.skillXp['Graphs'], 20);
    expect(s.badges, contains('first_commit'));
    expect(n.commitDay('again'), isNull);
    expect(c.read(appProvider).skillXp['Graphs'], 20);
  });

  test('2-minute version earns half xp', () {
    final c = make();
    final n = c.read(appProvider.notifier);
    final t = n.addTask(title: 'x', type: TaskType.dsa, skill: 'Arrays', difficulty: 2);
    n.toggleDone(t.id, fallback: true);
    expect(c.read(appProvider).tasks.single.xp, 10);
  });

  test('focus session converts minutes to skill xp', () {
    final c = make();
    final xp = c.read(appProvider.notifier).logFocus('Graphs', 25);
    expect(xp, 10);
    expect(c.read(appProvider).focusMinutes['Graphs'], 25);
    expect(c.read(appProvider).skillXp['Graphs'], 10);
  });

  test('double-day hotfix saves a streak that would have broken', () {
    final c = make();
    final n = c.read(appProvider.notifier);
    n.completeOnboarding(name: 'A', identity: 'x', skills: []);
    // history: committed 2 and 3 days ago, nothing yesterday, no stash.
    final s = c.read(appProvider);
    c.read(appProvider.notifier).state = s.copyWith(commits: [
      const DayCommit(day: '2026-11-06', tasks: 1),
      const DayCommit(day: '2026-11-07', tasks: 1),
    ]);
    for (final title in ['a', 'b']) {
      final t = n.addTask(title: title, type: TaskType.dsa, skill: 'Arrays');
      n.toggleDone(t.id);
    }
    final r = n.commitDay('double')!;
    expect(r.hotfixed, isTrue);
    expect(r.streak, 4);
  });

  test('state persists across containers', () {
    final c = make();
    c.read(appProvider.notifier).completeOnboarding(name: 'Persist', identity: 'x', skills: []);
    final c2 = make();
    expect(c2.read(appProvider).name, 'Persist');
  });

  testWidgets('onboarding gate then home renders', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), clockProvider.overrideWithValue(() => clock)],
      child: const CommitApp(),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Commit code.'), findsOneWidget);
  });
}
