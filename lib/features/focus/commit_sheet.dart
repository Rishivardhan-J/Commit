import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/polish.dart';
import '../../core/widgets/toast.dart';
import '../../data/app_store.dart';
import 'commit_grid.dart';
import 'focus_controller.dart';
import '../../core/icons.dart';

/// Shown when a focus block ends: review it, say how it went, and "commit" it to the log.
/// XP is already banked; this only annotates the log entry, so dismissing loses nothing.
Future<void> showCommitSheet(BuildContext context, FocusEvent e) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CommitSheet(event: e),
    );

class _CommitSheet extends ConsumerStatefulWidget {
  final FocusEvent event;
  const _CommitSheet({required this.event});
  @override
  ConsumerState<_CommitSheet> createState() => _CommitSheetState();
}

class _CommitSheetState extends ConsumerState<_CommitSheet> with SingleTickerProviderStateMixin {
  late final TextEditingController msg;
  late final AnimationController merge = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  String outcome = 'shipped';
  bool markDone = true;

  FocusEvent get e => widget.event;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appProvider).focusLog.where((f) => f.id == e.sessionId);
    msg = TextEditingController(text: s.isEmpty ? '' : s.first.message);
  }

  @override
  void dispose() {
    msg.dispose();
    merge.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final app = ref.read(appProvider.notifier);
    if (e.sessionId != null) app.updateFocusSession(e.sessionId!, message: msg.text.trim(), outcome: outcome);
    if (markDone && e.taskId != null && outcome != 'notyet') {
      final t = ref.read(appProvider).tasks.where((t) => t.id == e.taskId && !t.done);
      if (t.isNotEmpty) app.toggleDone(e.taskId!);
    }
    HapticFeedback.heavyImpact();
    if (!reducedMotion(context)) await merge.forward();
    if (!mounted) return;
    Navigator.pop(context);
    AppToast.show('Committed · ${e.minutes} min · +${e.xp} xp', icon: Icons.check_circle_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final s = ref.watch(appProvider);
    final session = s.focusLog.where((f) => f.id == e.sessionId);
    final inter = session.isEmpty ? 0 : session.first.interruptions;
    final away = session.isEmpty ? 0 : session.first.awaySec;
    final hasTask = e.taskId != null && s.tasks.any((t) => t.id == e.taskId && !t.done);

    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: AppTheme.mono(context, size: 22, weight: FontWeight.w800)),
            Text(l, style: context.text.labelSmall?.copyWith(color: cc.textSecondary)),
          ]),
        );

    return Stack(children: [
      if (e.cycleDone) Positioned.fill(child: ConfettiBurst(colors: [cc.warning, context.scheme.primary, cc.success, cc.gradientEnd])),
      Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (e.cycleDone) ...[Icon(AppIcons.lightning, size: 24, color: cc.warning), const SizedBox(width: 8)],
              Text(e.cycleDone ? 'Full cycle complete' : 'Block finished', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            Center(
              child: AnimatedBuilder(
                animation: merge,
                builder: (_, child) => Opacity(
                  opacity: 1 - merge.value * 0.9,
                  child: Transform.scale(scale: 1 - 0.85 * Curves.easeInCubic.transform(merge.value), child: child),
                ),
                child: SizedBox(
                  width: 190,
                  child: CommitGrid(
                    minutes: e.minutes.clamp(1, 120),
                    elapsedMin: e.minutes.toDouble(),
                    heat: cc.heat.sublist(1),
                    track: cc.surfaceRaised,
                    current: context.scheme.primary,
                    glow: cc.warning,
                    semanticsLabel: '${e.minutes} minutes committed',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat('${e.minutes}', 'minutes'),
              stat('+${e.xp}', 'xp'),
              stat('$inter', 'distractions'),
              stat(away == 0 ? '—' : '${(away / 60).round()}m', 'away'),
            ]),
            const SizedBox(height: 16),
            Text('Did you ship it?', style: context.text.labelLarge?.copyWith(color: cc.textSecondary)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'shipped', icon: Icon(AppIcons.check), label: Text('Shipped')),
                ButtonSegment(value: 'partly', icon: Icon(AppIcons.circleHalf), label: Text('Partly')),
                ButtonSegment(value: 'notyet', icon: Icon(AppIcons.x), label: Text('Not yet')),
              ],
              selected: {outcome},
              onSelectionChanged: (v) => setState(() => outcome = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msg,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Commit message', hintText: 'e.g. solved two-sum with a hash map'),
            ),
            if (hasTask)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: markDone,
                onChanged: (v) => setState(() => markDone = v ?? true),
                title: const Text('Mark the linked task done'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _commit, icon: const Icon(Icons.commit_rounded), label: const Text('Commit'))),
          ]),
        ),
      ),
    ]);
  }
}
