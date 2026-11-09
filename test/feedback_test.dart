import 'dart:convert';
import 'package:commit/app.dart';
import 'package:commit/core/widgets/toast.dart';
import 'package:commit/data/app_store.dart';
import 'package:commit/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  final clock = DateTime(2026, 11, 9, 20);

  ProviderContainer make(http.Client client) {
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => clock),
      httpClientProvider.overrideWithValue(client),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  http.Client mock({bool githubOk = true}) => MockClient((r) async {
        if (r.url.host == 'api.github.com') {
          if (!githubOk) return http.Response('', 404);
          if (r.url.path.endsWith('/events/public')) return http.Response('[]', 200);
          if (r.url.path.contains('/repos')) return http.Response('[]', 200);
          return http.Response(jsonEncode({'public_repos': 3, 'followers': 0}), 200);
        }
        return http.Response(
            jsonEncode({
              'data': {
                'matchedUser': {
                  'submitStatsGlobal': {'acSubmissionNum': [{'difficulty': 'All', 'count': 50}]},
                  'tagProblemCounts': {},
                  'userCalendar': {'streak': 1, 'submissionCalendar': '{}'},
                },
                'recentAcSubmissionList': [],
              }
            }),
            200);
      });

  test('sync report has a per-platform summary on success', () async {
    final c = make(mock());
    final n = c.read(appProvider.notifier);
    n.updateSettings(githubUser: 'a', leetcodeUser: 'b');
    final r = await n.sync(force: true);
    expect(r.allOk, isTrue);
    expect(r.results.map((x) => x.label), containsAll(['GitHub', 'LeetCode']));
    expect(r.results.firstWhere((x) => x.id == 'github').message, contains('3 repos'));
  });

  test('sync report isolates a failing platform', () async {
    final c = make(mock(githubOk: false));
    final n = c.read(appProvider.notifier);
    n.updateSettings(githubUser: 'nobody', leetcodeUser: 'b');
    final r = await n.sync(force: true);
    expect(r.anyFailed, isTrue);
    expect(r.results.firstWhere((x) => x.id == 'github').ok, isFalse);
    expect(r.results.firstWhere((x) => x.id == 'leetcode').ok, isTrue);
    expect(c.read(appProvider).syncErrors['github'], isNotNull);
  });

  test('no linked accounts yields an empty report', () async {
    final c = make(mock());
    final r = await c.read(appProvider.notifier).sync(force: true);
    expect(r.noAccounts, isTrue);
  });

  test('restoreTask and restoreWallet bring deleted items back once', () {
    final c = make(mock());
    final n = c.read(appProvider.notifier);
    final t = n.addTask(title: 'x', type: TaskType.dsa, skill: 'Arrays');
    n.deleteTask(t.id);
    expect(c.read(appProvider).tasks, isEmpty);
    n.restoreTask(t);
    n.restoreTask(t);
    expect(c.read(appProvider).tasks.length, 1);

    n.addWallet(const WalletItem(id: '', kind: WalletKind.idea, title: 'i'));
    final w = c.read(appProvider).wallet.single;
    n.deleteWallet(w.id);
    n.restoreWallet(w);
    n.restoreWallet(w);
    expect(c.read(appProvider).wallet.single.id, w.id);
  });

  testWidgets('toast shows message + Undo and replaces the previous one', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), clockProvider.overrideWithValue(() => clock)],
      child: const CommitApp(),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    var undone = false;
    AppToast.show('First', kind: ToastKind.info);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('First'), findsOneWidget);
    AppToast.show('Task deleted', actionLabel: 'Undo', onAction: () => undone = true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    await tester.tap(find.text('Undo'));
    expect(undone, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('bottom nav switches tabs and keeps each tab alive', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => clock),
      httpClientProvider.overrideWithValue(mock()),
    ]);
    addTearDown(container.dispose);
    container.read(appProvider.notifier).completeOnboarding(name: 'A', identity: 'x', skills: ['Arrays']);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CommitApp()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("Today's focus"), findsOneWidget);

    await tester.tap(find.text('Vault'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your vault is empty'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Today's focus"), findsOneWidget);
    expect(find.text('Your vault is empty'), findsNothing); // inactive tab is offstage
    await tester.pump(const Duration(seconds: 1));
  });
}
