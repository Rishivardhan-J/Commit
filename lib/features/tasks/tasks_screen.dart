import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/toast.dart';
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
  int dayOffset = 0; // Week view: 0 = today

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final todayTasks = s.tasks.where((t) => t.stagedFor == today || (t.done && t.doneDay == today)).toList();
    final backlog = s.tasks.where((t) => !t.done && (t.stagedFor == null || t.stagedFor!.compareTo(today) < 0)).toList();
    final planDay = addDays(today, dayOffset);
    final planned = s.tasks.where((t) => t.stagedFor == planDay || (dayOffset == 0 && t.done && t.doneDay == today)).toList();
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
            ButtonSegment(value: 1, label: Text('Week')),
            ButtonSegment(value: 2, label: Text('Backlog')),
            ButtonSegment(value: 3, label: Text('Skills')),
          ],
          showSelectedIcon: false,
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 12),
        if (tab == 0) list(todayTasks),
        if (tab == 1) ...[
          SizedBox(
            height: 76,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DayChip(
                    day: addDays(today, i),
                    selected: dayOffset == i,
                    count: s.tasks.where((t) => t.stagedFor == addDays(today, i) && !t.done).length,
                    onTap: () => setState(() => dayOffset = i),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (planned.isEmpty)
            CCard(
              child: EmptyState(
                emoji: '🗓️',
                title: dayOffset == 0 ? 'Nothing planned today' : 'Nothing planned yet',
                subtitle: 'Pull tasks from your backlog into this day.',
              ),
            )
          else
            list(planned),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: backlog.isEmpty
                ? () => AppToast.show('Your backlog is empty — add a task with +', kind: ToastKind.info)
                : () => _planSheet(context, backlog, planDay),
            icon: const Icon(Icons.event_available_rounded),
            label: Text(dayOffset == 0 ? 'Plan from backlog' : 'Plan for ${_dayName(planDay)}'),
          ),
        ],
        if (tab == 2) list(backlog, toggle: true),
        if (tab == 3)
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

String _dayName(String key) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][parseDayKey(key).weekday - 1];

class _DayChip extends StatelessWidget {
  final String day;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _DayChip({required this.day, required this.selected, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = context.scheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${_dayName(day)} ${parseDayKey(day).day}, $count planned',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          decoration: BoxDecoration(
            color: selected ? primary : cc.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_dayName(day), style: context.text.labelSmall?.copyWith(color: selected ? cc.onAccent : cc.textSecondary)),
            const SizedBox(height: 4),
            Text('${parseDayKey(day).day}',
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: selected ? cc.onAccent : null)),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count == 0 ? Colors.transparent : (selected ? cc.onAccent : cc.warning),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

void _planSheet(BuildContext context, List<Task> backlog, String day) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PlanSheet(backlog: backlog, day: day),
    );

class _PlanSheet extends ConsumerWidget {
  final List<Task> backlog;
  final String day;
  const _PlanSheet({required this.backlog, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(appProvider).tasks.where((t) => backlog.any((b) => b.id == t.id) && !t.done && t.stagedFor != day).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Plan for ${_dayName(day)} ${parseDayKey(day).day}', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (tasks.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Everything is planned.')),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final t in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.title),
                subtitle: Text('${t.skill} · +${t.xp} xp'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  ref.read(appProvider.notifier).stageFor(t.id, day);
                  AppToast.show('Planned for ${_dayName(day)}', icon: Icons.event_available_rounded);
                },
              ),
          ]),
        ),
      ]),
    );
  }
}
