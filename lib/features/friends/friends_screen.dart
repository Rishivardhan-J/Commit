import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/commit_logo.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../engine/coding_score.dart';

enum _Metric { score, week, solved }

class _Row {
  final String id, name;
  final bool me;
  final int score, week, solved;
  final String? note;
  const _Row(this.id, this.name, this.me, this.score, this.week, this.solved, this.note);
}

int _week(Map<String, PlatformSnapshot> snaps, String today) {
  final from = addDays(today, -6);
  var n = 0;
  for (final s in snaps.values) {
    for (final e in s.activity.entries) {
      if (e.key.compareTo(from) >= 0 && e.key.compareTo(today) <= 0) n += e.value;
    }
  }
  return n;
}

int _solved(Map<String, PlatformSnapshot> snaps) =>
    ((snaps['leetcode']?.stats['solved'] ?? 0) + (snaps['codeforces']?.stats['solved'] ?? 0)).toInt();

/// Ranks you and your friends using only public platform data (no accounts, no backend).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  _Metric metric = _Metric.score;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _refresh(force: false));
  }

  Future<void> _refresh({required bool force}) async {
    if (ref.read(appProvider).friends.isEmpty) return;
    setState(() => loading = true);
    final failed = await ref.read(appProvider.notifier).refreshFriends(force: force);
    if (!mounted) return;
    setState(() => loading = false);
    if (force) {
      failed == 0
          ? AppToast.show('Leaderboard updated', icon: Icons.leaderboard_rounded)
          : AppToast.show('$failed friend${failed == 1 ? '' : 's'} could not be fully refreshed — showing cached stats', kind: ToastKind.warn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final cc = context.cc;
    final rows = <_Row>[
      _Row('me', s.name.isEmpty ? 'You' : s.name, true, scoreFromSnapshots(s.snapshots), _week(s.snapshots, today), _solved(s.snapshots), null),
      for (final f in s.friends)
        _Row(f.id, f.name, false, scoreFromSnapshots(f.snapshots), _week(f.snapshots, today), _solved(f.snapshots),
            f.error ?? (f.snapshots.isEmpty && f.fetchedAt == null ? 'fetching…' : null)),
    ];
    int val(_Row r) => switch (metric) { _Metric.score => r.score, _Metric.week => r.week, _Metric.solved => r.solved };
    rows.sort((a, b) => val(b).compareTo(val(a)));
    final maxV = rows.isEmpty ? 1 : (val(rows.first) == 0 ? 1 : val(rows.first));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            onPressed: loading ? null : () => _refresh(force: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFriend(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add friend'),
        backgroundColor: context.scheme.primary,
        foregroundColor: cc.onAccent,
        elevation: 0,
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<_Metric>(
          segments: const [
            ButtonSegment(value: _Metric.score, label: Text('Score')),
            ButtonSegment(value: _Metric.week, label: Text('This week')),
            ButtonSegment(value: _Metric.solved, label: Text('Solved')),
          ],
          selected: {metric},
          onSelectionChanged: (v) => setState(() => metric = v.first),
        ),
        const SizedBox(height: 6),
        Text('Ranked from public GitHub, LeetCode and Codeforces data only.',
            style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
        const SizedBox(height: 12),
        if (s.friends.isEmpty)
          CCard(
            child: EmptyState(
              emoji: '🤝',
              title: 'Race your classmates',
              subtitle: 'Add a friend by their public usernames. No sign-up, no accounts.',
              cta: 'Add a friend',
              onCta: () => _showAddFriend(context),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaderRow(rank: i + 1, row: rows[i], value: val(rows[i]), max: maxV, metric: metric),
            ),
      ]),
    );
  }
}

class _LeaderRow extends ConsumerWidget {
  final int rank, value, max;
  final _Row row;
  final _Metric metric;
  const _LeaderRow({required this.rank, required this.row, required this.value, required this.max, required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
    final card = CCard(
      child: Row(children: [
        SizedBox(width: 34, child: Text(medal, style: TextStyle(fontSize: rank <= 3 ? 22 : 16, fontWeight: FontWeight.w800, color: cc.textSecondary))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(row.name, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              if (row.me) ...[const SizedBox(width: 8), Pill('you', color: context.scheme.primary)],
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / max,
                minHeight: 6,
                color: row.me ? context.scheme.primary : cc.resource,
                backgroundColor: cc.surfaceRaised,
              ),
            ),
            if (row.note != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(row.note!, style: context.text.labelSmall?.copyWith(color: cc.warning))),
          ]),
        ),
        const SizedBox(width: 12),
        Text('$value', style: AppTheme.mono(context, size: 20, weight: FontWeight.w800)),
      ]),
    );
    if (row.me) return card;
    return Dismissible(
      key: ValueKey('friend-${row.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: context.scheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.person_remove_rounded, color: context.scheme.error),
      ),
      onDismissed: (_) {
        final n = ref.read(appProvider.notifier);
        final f = ref.read(appProvider).friends.firstWhere((x) => x.id == row.id);
        n.removeFriend(row.id);
        AppToast.show('${row.name} removed', kind: ToastKind.info, icon: Icons.person_remove_rounded, actionLabel: 'Undo', onAction: () => n.restoreFriend(f));
      },
      child: card,
    );
  }
}

void _showAddFriend(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AddFriendSheet(),
    );

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();
  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> {
  final name = TextEditingController(), gh = TextEditingController(), lc = TextEditingController(), cf = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, gh, lc, cf]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return setState(() => error = 'Give your friend a name');
    if ([gh, lc, cf].every((c) => c.text.trim().isEmpty)) return setState(() => error = 'Add at least one username');
    setState(() {
      error = null;
      busy = true;
    });
    final n = ref.read(appProvider.notifier);
    n.addFriend(name: name.text.trim(), github: gh.text.trim(), leetcode: lc.text.trim(), codeforces: cf.text.trim());
    if (mounted) Navigator.pop(context);
    final failed = await n.refreshFriends(force: true);
    failed == 0
        ? AppToast.show('${name.text.trim()} added to the leaderboard', icon: Icons.person_add_alt_1_rounded)
        : AppToast.show('Added, but some stats could not be loaded — check the usernames', kind: ToastKind.warn);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CommitLogo(size: 40),
            const SizedBox(height: 12),
            TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: gh, autocorrect: false, decoration: const InputDecoration(labelText: 'GitHub username', prefixIcon: Icon(Icons.code))),
            const SizedBox(height: 10),
            TextField(controller: lc, autocorrect: false, decoration: const InputDecoration(labelText: 'LeetCode username', prefixIcon: Icon(Icons.terminal))),
            const SizedBox(height: 10),
            TextField(controller: cf, autocorrect: false, decoration: const InputDecoration(labelText: 'Codeforces handle', prefixIcon: Icon(Icons.bar_chart_rounded))),
            if (error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: context.scheme.error))),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : _save, child: const Text('Add friend'))),
          ]),
        ),
      );
}
