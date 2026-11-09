import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../engine/badge_engine.dart';
import '../../engine/xp_engine.dart';

/// The evening ritual: review the diff, write a one-line message, commit.
class CommitScreen extends ConsumerStatefulWidget {
  const CommitScreen({super.key});
  @override
  ConsumerState<CommitScreen> createState() => _CommitScreenState();
}

class _CommitScreenState extends ConsumerState<CommitScreen> {
  final msg = TextEditingController();
  CommitResult? result;

  static const _starters = ['small steps, real progress', 'fixed what was bugging me', 'learned something new', 'showed up'];

  @override
  void dispose() {
    msg.dispose();
    super.dispose();
  }

  void _commit() {
    final r = ref.read(appProvider.notifier).commitDay(msg.text);
    if (r == null) return;
    r.critical ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    setState(() => result = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final done = s.tasks.where((t) => t.done && t.doneDay == today).toList();
    final cc = context.cc;
    if (result != null) return _Celebration(result: result!);

    final xp = done.fold<int>(0, (a, t) => a + t.xp);
    final bonus = commitBonus(today, done.length);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => context.pop()),
        title: const Text('Commit the day'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Changes', style: context.text.labelLarge?.copyWith(color: cc.textSecondary)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cc.border),
                ),
                child: ListView(padding: const EdgeInsets.all(14), children: [
                  for (final t in done)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Text('+ ', style: AppTheme.mono(context, color: cc.success, weight: FontWeight.w800)),
                        Expanded(child: Text(t.title, style: AppTheme.mono(context, size: 13, weight: FontWeight.w500))),
                        Text('${t.skill} +${t.xp}', style: AppTheme.mono(context, size: 12, color: cc.warning)),
                      ]),
                    ),
                  const Divider(height: 24),
                  Text('$xp xp from tasks · +$bonus commit bonus',
                      style: AppTheme.mono(context, size: 12, color: cc.textSecondary)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msg,
              maxLength: 72,
              decoration: const InputDecoration(labelText: 'Commit message', hintText: 'What did you ship today?'),
            ),
            Wrap(spacing: 8, children: [
              for (final t in _starters)
                ActionChip(label: Text(t), onPressed: () => setState(() => msg.text = t)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: done.isEmpty ? null : _commit,
                icon: const Icon(Icons.commit_rounded),
                label: const Text('Commit'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  final CommitResult result;
  const _Celebration({required this.result});

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final total = result.taskXp + result.bonus;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(result.critical ? '⚡' : '🔥', style: const TextStyle(fontSize: 72))
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 12),
            Text(result.critical ? 'Critical commit!' : 'Committed.',
                style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (result.critical)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('2× bonus XP', style: TextStyle(color: cc.warning, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 20),
            Text('+$total xp', style: AppTheme.mono(context, size: 40, weight: FontWeight.w800, color: cc.warning))
                .animate()
                .fadeIn(delay: 200.ms)
                .slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text('${result.streak}-day streak', style: context.text.titleMedium),
            if (result.levelAfter > result.levelBefore)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Pill('Level up → ${result.levelAfter}', color: context.scheme.primary, icon: Icons.arrow_upward_rounded),
              ),
            if (result.hotfixed)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('🩹 Hotfix! Your double day repaired yesterday and saved the streak.', textAlign: TextAlign.center)),
            if (result.stashEarned)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('🧊 You earned a stash — it protects your streak if you miss a day.')),
            for (final id in result.newBadges)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${badgeById(id)?.emoji} Badge: ${badgeById(id)?.name}',
                    style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 32),
            FilledButton(onPressed: () => context.pop(), child: const Text('Done')),
          ]),
        ),
      ),
    );
  }
}
