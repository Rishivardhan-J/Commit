import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../capture/capture_sheet.dart';
import 'task_tile.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final todayTasks = s.tasks.where((t) => t.stagedFor == today || (t.done && t.doneDay == today)).toList();
    final backlog = s.tasks.where((t) => !t.done && t.stagedFor != today).toList();
    final bySkill = <String, List<Task>>{};
    for (final t in s.tasks) {
      (bySkill[t.skill] ??= []).add(t);
    }

    Widget list(List<Task> ts, {bool toggle = false}) => ts.isEmpty
        ? EmptyState(
            emoji: tab == 0 ? '✨' : '📭',
            title: tab == 0 ? 'A clean working tree' : 'Nothing here',
            subtitle: 'Tap + to add a task in a few seconds.',
            cta: 'Add a task',
            onCta: () => showCaptureSheet(context),
          )
        : CCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [for (final t in ts) TaskTile(task: t, showStageToggle: toggle)]),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks'), actions: [
        IconButton(tooltip: 'Goal roadmaps', icon: const Icon(Icons.map_outlined), onPressed: () => context.push('/roadmaps')),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Today')),
            ButtonSegment(value: 1, label: Text('Backlog')),
            ButtonSegment(value: 2, label: Text('By skill')),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 12),
        if (tab == 0) list(todayTasks),
        if (tab == 1) list(backlog, toggle: true),
        if (tab == 2)
          if (bySkill.isEmpty)
            list(const [])
          else
            for (final e in bySkill.entries) ...[
              SectionTitle(e.key, trailing: Text('${e.value.where((t) => t.done).length}/${e.value.length}', style: TextStyle(color: context.cc.textSecondary))),
              list(e.value, toggle: true),
            ],
      ]),
    );
  }
}
