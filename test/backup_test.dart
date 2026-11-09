import 'package:commit/data/models.dart';
import 'package:commit/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final state = AppState(
    onboarded: true,
    name: 'Ada',
    tasks: const [Task(id: 't', title: 'x', type: TaskType.dsa, skill: 'Arrays')],
    commits: const [DayCommit(day: '2026-11-09', tasks: 1, xp: 30, bonus: 25)],
    wallet: const [WalletItem(id: 'w', kind: WalletKind.snippet, title: 's', body: 'print(1)', extra: {'lang': 'python'})],
    friends: const [Friend(id: 'f', name: 'Bob', leetcode: 'bob')],
    claimedChallenges: const ['2026-W46:streak'],
  );

  test('export then parse round-trips everything', () {
    final raw = BackupService.encode(state, DateTime(2026, 11, 9));
    final p = BackupService.parse(raw);
    expect(p.state.name, 'Ada');
    expect(p.tasks, 1);
    expect(p.commits, 1);
    expect(p.friends, 1);
    expect(p.state.wallet.single.kind, WalletKind.snippet);
    expect(p.state.wallet.single.extra['lang'], 'python');
    expect(p.state.claimedChallenges, ['2026-W46:streak']);
    expect(p.exportedAt, DateTime(2026, 11, 9));
  });

  test('rejects non-JSON, foreign JSON and newer versions with clear messages', () {
    expect(() => BackupService.parse('nope'), throwsA(isA<FormatException>()));
    expect(() => BackupService.parse('{"hello":1}'), throwsA(isA<FormatException>()));
    expect(() => BackupService.parse('{"app":"commit","version":99,"state":{}}'),
        throwsA(predicate((e) => e is FormatException && e.message.contains('newer'))));
    expect(() => BackupService.parse('{"app":"commit","version":2,"state":{"tasks":"bad"}}'),
        throwsA(isA<FormatException>()));
  });
}
