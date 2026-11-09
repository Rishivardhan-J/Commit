import 'package:commit/data/app_store.dart';
import 'package:commit/data/models.dart';
import 'package:commit/features/focus/commit_grid.dart';
import 'package:commit/features/focus/focus_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  var now = DateTime(2026, 11, 9, 10);

  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    now = DateTime(2026, 11, 9, 10);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('start counts down from a wall-clock end', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setLength(25);
    f.start();
    now = now.add(const Duration(minutes: 10));
    expect(c.read(focusProvider).remaining(now), const Duration(minutes: 15));
    expect(c.read(focusProvider).progress(now), closeTo(0.4, 0.001));
  });

  test('pause freezes remaining time and resume continues from it', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setLength(25);
    f.start();
    now = now.add(const Duration(minutes: 5));
    f.pause();
    now = now.add(const Duration(minutes: 30)); // time passes while paused
    expect(c.read(focusProvider).remaining(now), const Duration(minutes: 20));
    f.resume();
    now = now.add(const Duration(minutes: 20));
    expect(c.read(focusProvider).remaining(now), Duration.zero);
  });

  test('+5 min extends the phase', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setLength(25);
    f.start();
    f.addFive();
    expect(c.read(focusProvider).remaining(now), const Duration(minutes: 30));
  });

  test('finishing a focus block logs xp and starts a short break', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setSkill('Graphs');
    f.setLength(25);
    f.start();
    now = now.add(const Duration(minutes: 25, seconds: 1));
    f.evaluate();
    final s = c.read(focusProvider);
    expect(s.phase, FocusPhase.shortBreak);
    expect(s.event?.minutes, 25);
    expect(s.event?.xp, 10);
    expect(s.cycleIndex, 1);
    expect(c.read(appProvider).focusMinutes['Graphs'], 25);
    // break then returns to idle, not auto-starting another block
    now = now.add(const Duration(minutes: 5, seconds: 1));
    f.evaluate();
    expect(c.read(focusProvider).phase, FocusPhase.idle);
  });

  test('fourth block earns a long break and resets the cycle', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setLength(25);
    for (var i = 0; i < 4; i++) {
      f.start();
      now = now.add(const Duration(minutes: 25, seconds: 1));
      f.evaluate();
      if (i < 3) {
        now = now.add(const Duration(minutes: 5, seconds: 1));
        f.evaluate();
      }
    }
    final s = c.read(focusProvider);
    expect(s.phase, FocusPhase.longBreak);
    expect(s.event?.cycleDone, isTrue);
    expect(s.cycleIndex, 0);
    expect(c.read(appProvider).focusMinutes['General'], 100);
  });

  test('stop logs only whole minutes focused; under a minute logs nothing', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.start();
    now = now.add(const Duration(seconds: 40));
    expect(f.stop(), isNull);
    f.start();
    now = now.add(const Duration(minutes: 7, seconds: 30));
    final ev = f.stop();
    expect(ev?.minutes, 7);
    expect(c.read(focusProvider).phase, FocusPhase.idle);
  });

  test('a running timer survives an app restart and completes if overdue', () {
    final c1 = make();
    final f = c1.read(focusProvider.notifier);
    f.setSkill('Arrays');
    f.setLength(25);
    f.start();
    // app killed; reopened 30 minutes later
    now = now.add(const Duration(minutes: 30));
    final c2 = make();
    expect(c2.read(focusProvider).running, isTrue);
    c2.read(focusProvider.notifier).evaluate();
    expect(c2.read(focusProvider).phase, FocusPhase.shortBreak);
    expect(c2.read(appProvider).focusMinutes['Arrays'], 25);
  });

  test('grid geometry is roughly square with 5..10 columns', () {
    expect(gridDims(25), (cols: 5, rows: 5));
    expect(gridDims(5), (cols: 5, rows: 1));
    expect(gridDims(90), (cols: 10, rows: 9));
    expect(gridDims(120), (cols: 11.clamp(5, 10), rows: 12));
  });

  test('finished block writes a log entry with the intention and distractions', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.setLength(25);
    f.setSkill('Arrays');
    f.setIntention('solve two-sum');
    f.start();
    f.addInterruption();
    now = now.add(const Duration(minutes: 25, seconds: 1));
    f.evaluate();
    final log = c.read(appProvider).focusLog;
    expect(log, hasLength(1));
    expect(log.single.message, 'solve two-sum');
    expect(log.single.minutes, 25);
    expect(log.single.interruptions, 1);
    expect(c.read(focusProvider).event?.sessionId, log.single.id);
    c.read(appProvider.notifier).updateFocusSession(log.single.id, outcome: 'partly');
    expect(c.read(appProvider).focusLog.single.outcome, 'partly');
  });

  test('time away of 10s+ counts as a context switch; short blips do not', () {
    final c = make();
    final f = c.read(focusProvider.notifier);
    f.start();
    f.leftApp();
    now = now.add(const Duration(seconds: 5));
    expect(f.returnedToApp(), isNull);
    f.leftApp();
    now = now.add(const Duration(seconds: 90));
    expect(f.returnedToApp(), const Duration(seconds: 90));
    expect(c.read(focusProvider).interruptions, 1);
    expect(c.read(focusProvider).awaySec, 90);
  });

  test('focus log is capped', () {
    final c = make();
    final n = c.read(appProvider.notifier);
    for (var i = 0; i < 205; i++) {
      n.addFocusSession(FocusSession(id: 'id-$i-aaaaaaaa', day: '2026-11-09', skill: 'x', minutes: 1));
    }
    expect(c.read(appProvider).focusLog, hasLength(200));
    expect(c.read(appProvider).focusLog.first.id, 'id-5-aaaaaaaa');
  });
}
