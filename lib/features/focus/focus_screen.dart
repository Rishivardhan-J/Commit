import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../services/notification_service.dart';
import '../capture/capture_sheet.dart' show defaultSkills;
import 'ambient.dart';
import 'commit_grid.dart';
import 'commit_sheet.dart';
import 'focus_controller.dart';
import 'ruler.dart';
import '../../core/icons.dart';

/// "Commit grid" focus timer: one square per minute fills like a contribution graph, you write
/// a commit message first, and every finished block lands in a git-style log.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController frame; // drives 60fps repaints while running
  late final TextEditingController intent;
  bool deep = false;
  int logShown = 6;
  int _lastMinute = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    frame = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_onFrame);
    intent = TextEditingController(text: ref.read(focusProvider).intention);
    Future.microtask(() => ref.read(focusProvider.notifier).evaluate());
  }

  void _onFrame() {
    final ctl = ref.read(focusProvider.notifier);
    ctl.evaluate();
    // a light tick each time another minute gets committed
    final fs = ref.read(focusProvider);
    if (fs.phase == FocusPhase.focus && fs.running) {
      final m = ((fs.phaseTotalSec - fs.remaining(ref.read(clockProvider)()).inSeconds) / 60).floor();
      if (_lastMinute >= 0 && m > _lastMinute) HapticFeedback.lightImpact();
      _lastMinute = m;
    } else {
      _lastMinute = -1;
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final ctl = ref.read(focusProvider.notifier);
    if (s == AppLifecycleState.paused) {
      ctl.leftApp();
    } else if (s == AppLifecycleState.resumed) {
      ctl.evaluate();
      final away = ctl.returnedToApp();
      if (away != null) {
        final m = away.inMinutes, sec = away.inSeconds % 60;
        AppToast.show('You were away ${m > 0 ? '${m}m ' : ''}${sec}s — counted as a context switch',
            kind: ToastKind.info, icon: Icons.swap_horiz_rounded);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    frame.dispose();
    intent.dispose();
    _setDeep(false, notify: false);
    super.dispose();
  }

  void _setDeep(bool v, {bool notify = true}) {
    deep = v;
    if (v) {
      WakelockPlus.enable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (notify && mounted) setState(() {});
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  void _onEvent(FocusEvent e) {
    final ctl = ref.read(focusProvider.notifier);
    ctl.clearEvent();
    if (e.ended == FocusPhase.focus) {
      HapticFeedback.heavyImpact();
      if (deep) _setDeep(false);
      showCommitSheet(context, e);
    } else {
      HapticFeedback.mediumImpact();
      AppToast.show('Break over — ready for the next block?', kind: ToastKind.info, icon: Icons.play_circle_rounded);
    }
  }

  void _soundSheet() => showModalBottomSheet(
        context: context,
        builder: (_) => Consumer(builder: (context, ref, _) {
          final fs = ref.watch(focusProvider);
          final ctl = ref.read(focusProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ambient sound', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('Plays during focus blocks, silent on breaks.', style: context.text.bodySmall?.copyWith(color: context.cc.textSecondary)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in ambientSounds)
                  ChoiceChip(
                    avatar: Icon(s.icon, size: 18),
                    label: Text(s.label),
                    selected: fs.sound == s.id,
                    onSelected: (_) => ctl.setSound(s.id),
                  ),
              ]),
              if (fs.sound != 'none') ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(child: Slider(value: fs.volume, onChanged: ctl.setVolume)),
                  const Icon(Icons.volume_up_rounded),
                ]),
              ],
            ]),
          );
        }),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(focusProvider.select((s) => s.event), (_, e) {
      if (e != null) _onEvent(e);
    });
    final fs = ref.watch(focusProvider);
    final app = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final ctl = ref.read(focusProvider.notifier);
    final cc = context.cc;
    final scheme = context.scheme;
    final now = ref.read(clockProvider)();

    final remaining = fs.remaining(now);
    final secs = remaining.inSeconds + (remaining.inMilliseconds % 1000 > 0 && fs.running ? 1 : 0);
    final isBreak = fs.isBreak;
    final accent = isBreak ? cc.resource : scheme.primary;
    final totalMin = (fs.phaseTotalSec / 60).ceil();
    final elapsedMin = fs.active ? (fs.phaseTotalSec - remaining.inMilliseconds / 1000) / 60 : 0.0;
    final skills = {...app.focusSkills, ...defaultSkills}.toList();
    final skill = fs.skill ?? skills.first;
    final stagedTasks = app.tasks.where((t) => !t.done && t.stagedFor == today).toList();
    final todayMin = app.focusByDay[today] ?? 0;
    final slug = skill.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    if (fs.running && !frame.isAnimating) {
      frame.repeat();
    } else if (!fs.running && frame.isAnimating) {
      frame.stop();
    }

    final timeStyle = AppTheme.mono(context, size: 60, weight: FontWeight.w800).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final timeLabel = '${_two(secs ~/ 60)}:${_two(secs % 60)}';

    final grid = CommitGrid(
      minutes: fs.active ? totalMin : fs.focusMin,
      elapsedMin: elapsedMin,
      heat: isBreak ? [cc.resource.withValues(alpha: 0.35), cc.resource] : cc.heat.sublist(1),
      track: cc.surfaceRaised,
      current: accent,
      glow: isBreak ? cc.resource : cc.warning,
      dim: deep,
      onLengthChanged: fs.active ? null : ctl.setLength,
      semanticsLabel: fs.active
          ? '${elapsedMin.floor()} of $totalMin minutes committed, ${secs ~/ 60} minutes ${secs % 60} seconds remaining'
          : '${fs.focusMin} minute session. Drag to change length.',
    );

    final status = switch (fs.phase) {
      FocusPhase.idle => ('ready', cc.textSecondary, Icons.circle_outlined),
      FocusPhase.focus => fs.running ? ('building', cc.warning, Icons.circle) : ('paused', cc.textSecondary, Icons.pause_circle_outline_rounded),
      _ => ('on a break', cc.resource, Icons.coffee_rounded),
    };

    if (deep && fs.active) {
      final drift = Offset((now.minute % 7 - 3) * 3.0, (now.minute % 5 - 2) * 3.0); // avoid OLED burn-in
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setDeep(false),
          child: SafeArea(
            child: Transform.translate(
              offset: drift,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (isBreak) BreathingSquare(color: accent, style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)) else grid,
                  const SizedBox(height: 28),
                  Text(timeLabel, style: timeStyle.copyWith(color: Colors.white70)),
                  const SizedBox(height: 18),
                  Text('tap to exit deep focus', style: context.text.bodySmall?.copyWith(color: Colors.white24)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget cycleGraph() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < cycleLength; i++) ...[
            if (i > 0)
              Container(width: 26, height: 2, color: i <= fs.cycleIndex ? scheme.primary : cc.surfaceRaised),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < fs.cycleIndex || (isBreak && i <= fs.cycleIndex) ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i == fs.cycleIndex && fs.phase == FocusPhase.focus ? cc.warning : (i <= fs.cycleIndex ? scheme.primary : cc.border),
                  width: 2,
                ),
              ),
            ),
          ],
        ]);

    Widget dock() {
      if (!fs.active) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await NotificationService.instance.requestPermission();
              ctl.start();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Start ${fs.focusMin} min block'),
          ),
        );
      }
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundButton(
          icon: Icons.stop_rounded,
          label: 'Hold to stop',
          onTap: () => AppToast.show('Press and hold to stop the block', kind: ToastKind.info, icon: Icons.touch_app_rounded),
          onLongPress: () {
            HapticFeedback.heavyImpact();
            final ev = ctl.stop();
            if (ev != null) {
              showCommitSheet(context, ev);
            } else if (fs.phase == FocusPhase.focus) {
              AppToast.show('Under a minute — nothing logged', kind: ToastKind.info, icon: Icons.timer_off_rounded);
            }
          },
        ),
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(value: fs.progress(now), strokeWidth: 4, color: accent, backgroundColor: cc.surfaceRaised),
          ),
          Semantics(
            button: true,
            label: fs.running ? 'Pause' : 'Resume',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                fs.running ? ctl.pause() : ctl.resume();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 66,
                height: 66,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                child: Icon(fs.running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: cc.onAccent),
              ),
            ),
          ),
        ]),
        isBreak
            ? _RoundButton(icon: Icons.skip_next_rounded, label: 'Skip break', onTap: ctl.skipBreak)
            : _RoundButton(icon: Icons.more_time_rounded, label: '+5 min', onTap: ctl.addFive),
      ]);
    }

    final log = app.focusLog.reversed.toList();
    final focusDays = {for (final e in app.focusByDay.entries) e.key: (e.value / 15).ceil()};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        actions: [
          IconButton(
            tooltip: 'Ambient sound',
            icon: Icon(fs.sound == 'none' ? Icons.volume_off_rounded : Icons.graphic_eq_rounded, color: fs.sound == 'none' ? null : scheme.primary),
            onPressed: _soundSheet,
          ),
          if (fs.active)
            IconButton(tooltip: 'Deep focus mode', icon: const Icon(Icons.fullscreen_rounded), onPressed: () => _setDeep(true)),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
          Row(children: [
            Expanded(
              child: Text('focus/$slug', overflow: TextOverflow.ellipsis, style: AppTheme.mono(context, size: 15, weight: FontWeight.w700)),
            ),
            Pill(status.$1, color: status.$2, icon: status.$3),
          ]),
          const SizedBox(height: 12),
          if (!fs.active)
            TextField(
              controller: intent,
              onChanged: ctl.setIntention,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Commit message', hintText: 'What will you ship in this block?'),
            )
          else if (fs.intention.trim().isNotEmpty && !isBreak)
            Row(children: [
              Icon(Icons.commit_rounded, size: 18, color: cc.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(fs.intention.trim(), style: context.text.bodyMedium)),
            ]),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: isBreak
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: BreathingSquare(color: accent, style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)))
                  : grid,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: OdometerText(timeLabel, style: timeStyle)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              !fs.active
                  ? 'drag the grid or the ruler to set the length'
                  : isBreak
                      ? 'recharge — your next block is waiting'
                      : '${elapsedMin.floor()} of $totalMin commits',
              style: context.text.bodySmall?.copyWith(color: cc.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          cycleGraph(),
          const SizedBox(height: 22),
          if (!fs.active) ...[
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              for (final m in const [15, 25, 50, 90])
                ChoiceChip(label: Text('$m'), selected: fs.focusMin == m, onSelected: (_) => ctl.setLength(m)),
            ]),
            LengthRuler(minutes: fs.focusMin, onChanged: ctl.setLength),
            const SizedBox(height: 8),
          ],
          dock(),
          if (fs.active && fs.phase == FocusPhase.focus)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ctl.addInterruption();
                  AppToast.show('Distraction logged — back to it', kind: ToastKind.info, icon: Icons.flag_rounded);
                },
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(fs.interruptions == 0 ? 'I got distracted' : 'Distractions: ${fs.interruptions} · log another'),
              ),
            ),
          if (!fs.active) ...[
            const SectionTitle('Link a task'),
            if (stagedTasks.isEmpty)
              Text('No staged tasks — just pick a skill below.', style: context.text.bodySmall?.copyWith(color: cc.textSecondary))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final Task t in stagedTasks)
                  ChoiceChip(
                    label: Text(t.title, overflow: TextOverflow.ellipsis),
                    selected: fs.taskId == t.id,
                    onSelected: (v) {
                      ctl.setTask(v ? t.id : null, skill: v ? t.skill : null);
                      if (v && intent.text.trim().isEmpty) {
                        intent.text = t.title;
                        ctl.setIntention(t.title);
                      }
                    },
                  ),
              ]),
            const SectionTitle('Skill'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in skills) ChoiceChip(label: Text(k), selected: skill == k, onSelected: (_) => ctl.setSkill(k)),
            ]),
          ],
          const SectionTitle('Today'),
          CCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$todayMin', style: AppTheme.mono(context, size: 26, weight: FontWeight.w800)),
                Text(' / ${fs.dailyGoal} min', style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)),
                const Spacer(),
                if (todayMin >= fs.dailyGoal) Pill('goal hit', color: cc.success, icon: Icons.check_rounded),
                IconButton(
                  tooltip: 'Daily goal',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => SimpleDialog(title: const Text('Daily focus goal'), children: [
                      for (final g in const [30, 60, 100, 150, 240])
                        SimpleDialogOption(onPressed: () {
                          ctl.setDailyGoal(g);
                          Navigator.pop(c);
                        }, child: Row(children: [Expanded(child: Text('$g minutes')), if (g == fs.dailyGoal) Icon(AppIcons.check, size: 18)])),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (todayMin / fs.dailyGoal).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: todayMin >= fs.dailyGoal ? cc.success : scheme.primary,
                  backgroundColor: cc.surfaceRaised,
                ),
              ),
            ]),
          ),
          const SectionTitle('Focus days'),
          CCard(child: Heatmap(activity: focusDays, today: today, weeks: 12)),
          const SectionTitle('Focus log'),
          if (log.isEmpty)
            CCard(
              child: EmptyState(icon: AppIcons.plant, title: 'No commits yet', subtitle: 'Finish a block and it lands here like a git log.'),
            )
          else ...[
            CCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                for (final f in log.take(logShown)) _LogRow(f),
              ]),
            ),
            if (log.length > logShown)
              Center(child: TextButton(onPressed: () => setState(() => logShown += 10), child: const Text('Show more'))),
          ],
        ]),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final FocusSession f;
  const _LogRow(this.f);
  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final glyph = switch (f.outcome) { 'partly' => AppIcons.circleHalf, 'notyet' => AppIcons.xCircle, _ => AppIcons.checkCircle };
    final color = switch (f.outcome) { 'partly' => cc.warning, 'notyet' => context.scheme.error, _ => cc.success };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(f.hash, style: AppTheme.mono(context, size: 12, color: cc.warning)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.message.isEmpty ? '(no message)' : f.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
            Text('${f.skill} · ${f.minutes} min${f.interruptions > 0 ? ' · ${f.interruptions} distractions' : ''} · ${f.day}',
                style: context.text.labelSmall?.copyWith(color: cc.textSecondary)),
          ]),
        ),
        Icon(glyph, size: 20, color: color),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          onLongPress: onLongPress,
          radius: 34,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.cc.border, width: 1.5)),
            child: Icon(icon, size: 26),
          ),
        ),
      );
}
