import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../engine/autocomplete_engine.dart';

class TaskTile extends ConsumerWidget {
  final Task task;
  final bool showStageToggle;
  const TaskTile({super.key, required this.task, this.showStageToggle = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final n = ref.read(appProvider.notifier);
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final progress = ruleProgress(s, task, today);
    final done = task.done;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: context.scheme.error.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: context.scheme.error),
      ),
      onDismissed: (_) => n.deleteTask(task.id),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          n.toggleDone(task.id);
        },
        onLongPress: done
            ? null
            : () {
                HapticFeedback.selectionClick();
                n.toggleDone(task.id, fallback: true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Minimum viable commit logged — streak safe ✓'),
                  duration: const Duration(seconds: 2),
                ));
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? cc.success : Colors.transparent,
                border: Border.all(color: done ? cc.success : cc.border, width: 2),
              ),
              child: done ? Icon(Icons.check, size: 16, color: cc.onAccent) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? cc.textSecondary : null,
                    )),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Pill(task.skill, color: context.scheme.primary),
                  Pill('+${task.xp} xp', color: cc.warning),
                  if (task.auto) Pill('CI passed', color: cc.success, icon: Icons.bolt_rounded),
                  if (task.doneViaFallback) Pill('2-min version', color: cc.info),
                  if (progress != null && !done) Pill('${progress.have}/${progress.need} auto', color: cc.info, icon: Icons.sync_rounded),
                ]),
                if (!done && task.fallback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Tough day? Hold: ${task.fallback}',
                        style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
                  ),
              ]),
            ),
            if (showStageToggle && !done)
              IconButton(
                tooltip: task.stagedFor == null ? 'Stage for today' : 'Unstage',
                icon: Icon(task.stagedFor == null ? Icons.add_circle_outline : Icons.remove_circle_outline),
                onPressed: () => task.stagedFor == null ? n.stage(task.id) : n.unstage(task.id),
              ),
          ]),
        ),
      ),
    );
  }
}
