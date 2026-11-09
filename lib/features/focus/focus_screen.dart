import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../capture/capture_sheet.dart';

/// Pomodoro focus timer. Time is derived from a wall-clock end instant so it
/// stays correct when the app is backgrounded.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int minutes = 25;
  String? skill;
  DateTime? endsAt;
  Timer? ticker;
  int? finishedXp;

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Duration get left => endsAt == null ? Duration(minutes: minutes) : endsAt!.difference(DateTime.now());

  void start() {
    HapticFeedback.mediumImpact();
    setState(() {
      endsAt = DateTime.now().add(Duration(minutes: minutes));
      finishedXp = null;
    });
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left <= Duration.zero) {
        _finish(minutes);
      } else {
        setState(() {});
      }
    });
  }

  void _finish(int spent) {
    ticker?.cancel();
    final sk = skill ?? _skills().first;
    final xp = ref.read(appProvider.notifier).logFocus(sk, spent);
    HapticFeedback.heavyImpact();
    setState(() {
      endsAt = null;
      finishedXp = xp;
    });
    AppToast.show('Focus session logged · $spent min · +$xp $sk xp', icon: Icons.self_improvement_rounded);
  }

  /// Stop early: only whole minutes actually focused count.
  void stopEarly() {
    final spent = (Duration(minutes: minutes) - left).inMinutes;
    ticker?.cancel();
    if (spent >= 1) {
      _finish(spent);
    } else {
      setState(() => endsAt = null);
      AppToast.show('Under a minute — nothing logged', kind: ToastKind.info, icon: Icons.timer_off_rounded);
    }
  }

  List<String> _skills() {
    final s = ref.read(appProvider);
    final all = {...s.focusSkills, ...defaultSkills}.toList();
    return all.isEmpty ? ['General'] : all;
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final skills = _skills();
    final sel = skill ?? skills.first;
    final running = endsAt != null;
    final total = Duration(minutes: minutes);
    final remaining = left.isNegative ? Duration.zero : left;
    final progress = running ? 1 - remaining.inSeconds / total.inSeconds : 0.0;
    String two(int n) => n.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: cc.surfaceRaised,
                    color: context.scheme.primary,
                  ),
                ),
                Text('${two(remaining.inMinutes)}:${two(remaining.inSeconds % 60)}',
                    style: AppTheme.mono(context, size: 48, weight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          if (finishedXp != null)
            Center(child: Pill('Session logged · +$finishedXp $sel xp', color: cc.success, icon: Icons.check_rounded)),
          if (!running) ...[
            const SectionTitle('Length'),
            Wrap(spacing: 8, children: [
              for (final m in [15, 25, 45, 60])
                ChoiceChip(label: Text('$m min'), selected: minutes == m, onSelected: (_) => setState(() => minutes = m)),
            ]),
            const SectionTitle('Skill'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in skills)
                ChoiceChip(label: Text(k), selected: sel == k, onSelected: (_) => setState(() => skill = k)),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start focus')),
          ] else ...[
            Center(child: Text('Focusing on $sel', style: context.text.titleMedium)),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: stopEarly, child: const Text('Stop & log what I did')),
          ],
        ]),
      ),
    );
  }
}
