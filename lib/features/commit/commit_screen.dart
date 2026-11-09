import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/commit_logo.dart';
import '../../core/widgets/polish.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../engine/badge_engine.dart';
import '../../engine/xp_engine.dart';
import '../../core/icons.dart';

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

class _Celebration extends ConsumerStatefulWidget {
  final CommitResult result;
  const _Celebration({required this.result});
  @override
  ConsumerState<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends ConsumerState<_Celebration> {
  final cardKey = GlobalKey();
  bool sharing = false;

  Future<void> _share() async {
    setState(() => sharing = true);
    try {
      final boundary = cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/commit-day-${widget.result.streak}.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Day ${widget.result.streak} committed on Commit 🔥',
      ));
    } catch (_) {
      AppToast.show('Could not create the share image', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final cc = context.cc;
    final total = result.taskXp + result.bonus;
    final name = ref.read(appProvider).name;
    final big = result.critical || result.levelAfter > result.levelBefore || result.newBadges.isNotEmpty;
    return Scaffold(
      body: Stack(children: [
        if (big)
          Positioned.fill(
            child: ConfettiBurst(colors: [cc.warning, context.scheme.primary, cc.gradientEnd, cc.success, Colors.white]),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              RepaintBoundary(
                key: cardKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.scheme.primary, cc.gradientEnd],
                    ),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: cc.onAccent),
                    child: Column(children: [
                      const CommitLogo(size: 44),
                      const SizedBox(height: 14),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (result.critical) ...[Icon(AppIcons.lightning, size: 24, color: cc.onAccent), const SizedBox(width: 6)],
                        Text(result.critical ? 'Critical commit' : 'Day committed', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      AnimatedCount(
                        value: result.streak,
                        style: AppTheme.mono(context, size: 64, weight: FontWeight.w800, color: cc.onAccent),
                      ),
                      const Text('day streak', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Text('+$total xp${name.isEmpty ? '' : ' · $name'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ).animate().scale(begin: const Offset(0.9, 0.9), duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
              if (result.critical) Text('2× bonus XP', style: TextStyle(color: cc.warning, fontWeight: FontWeight.w800)),
              if (result.levelAfter > result.levelBefore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Pill('Level up → ${result.levelAfter}', color: context.scheme.primary, icon: Icons.arrow_upward_rounded),
                ),
              if (result.hotfixed)
                Padding(padding: const EdgeInsets.only(top: 12), child: _NoteRow(AppIcons.bandaids, 'Hotfix! Your double day repaired yesterday and saved the streak.')),
              if (result.stashEarned)
                Padding(padding: const EdgeInsets.only(top: 12), child: _NoteRow(AppIcons.snowflake, 'You earned a stash — it protects your streak if you miss a day.')),
              for (final id in result.newBadges)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(badgeById(id)?.icon ?? AppIcons.medal, size: 22, color: context.scheme.primary),
                    const SizedBox(width: 8),
                    Text('Badge: ${badgeById(id)?.name}', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sharing ? null : _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(sharing ? 'Preparing…' : 'Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => context.pop(), child: const Text('Done'))),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: context.scheme.primary),
        const SizedBox(width: 8),
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ]);
}
