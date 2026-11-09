import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/commit_logo.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../capture/capture_sheet.dart';
import '../../core/icons.dart';

const identities = {
  'Backend developer': ['System Design', 'Python', 'Databases'],
  'Competitive programmer': ['Arrays', 'Graphs', 'Dynamic Programming'],
  'Mobile developer': ['Flutter', 'System Design', 'Open Source'],
  'ML engineer': ['Machine Learning', 'Python', 'Math'],
  'Open-source contributor': ['Open Source', 'Git', 'Communication'],
  'Full-stack builder': ['React', 'Databases', 'System Design'],
};

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final page = PageController();
  int step = 0;
  final name = TextEditingController();
  final gh = TextEditingController();
  final lc = TextEditingController();
  final cf = TextEditingController();
  final task = TextEditingController();
  String? identity;
  final skills = <String>{};
  String? ghMsg, lcMsg, cfMsg;
  bool checking = false;

  @override
  void dispose() {
    page.dispose();
    name.dispose();
    gh.dispose();
    lc.dispose();
    cf.dispose();
    task.dispose();
    super.dispose();
  }

  void next() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    if (step < 3) {
      page.nextPage(duration: 300.ms, curve: Curves.easeOut);
      setState(() => step++);
    }
  }

  Future<void> _link() async {
    final n = ref.read(appProvider.notifier);
    setState(() {
      checking = true;
      ghMsg = lcMsg = cfMsg = null;
    });
    Future<String?> check(String platform, String user) async {
      if (user.trim().isEmpty) return null;
      try {
        final snap = await n.probe(platform, user.trim());
        n.cacheSnapshot(snap);
        return platform == 'github'
            ? 'ok:${snap.stats['repos']} repos found'
            : 'ok:${snap.stats['solved'] ?? 0} problems solved';
      } catch (e) {
        return 'err:$e';
      }
    }

    final r = await Future.wait([check('github', gh.text), check('leetcode', lc.text), check('codeforces', cf.text)]);
    if (!mounted) return;
    setState(() {
      ghMsg = r[0];
      lcMsg = r[1];
      cfMsg = r[2];
      checking = false;
    });
    final ok = !(r.any((m) => m != null && m.startsWith('err:')));
    if (ok) next();
  }

  void _finish() {
    final n = ref.read(appProvider.notifier);
    final focus = skills.isEmpty ? (identities[identity] ?? ['Arrays']) : skills.toList();
    n.completeOnboarding(
      name: name.text.trim(),
      identity: identity ?? 'developer',
      skills: focus,
      github: ghMsg?.startsWith('ok:') == true ? gh.text.trim() : '',
      leetcode: lcMsg?.startsWith('ok:') == true ? lc.text.trim() : '',
      codeforces: cfMsg?.startsWith('ok:') == true ? cf.text.trim() : '',
    );
    final title = task.text.trim();
    if (title.isNotEmpty) {
      final t = n.addTask(title: title, type: TaskType.learning, skill: focus.first, difficulty: 1);
      n.toggleDone(t.id, fallback: false); // endowed progress: first change already staged and done
    }
    n.commitDay('initial commit');
    AppToast.show('Initial commit made — day 1 of your streak starts now', icon: Icons.eco_rounded);
  }

  Widget _result(String m) {
    final ok = m.startsWith('ok:');
    final color = ok ? context.cc.success : context.scheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(ok ? AppIcons.checkCircle : AppIcons.warningCircle, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(m.substring(m.indexOf(':') + 1), style: TextStyle(color: color))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    Widget shell(IconData icon, String title, String sub, Widget body, Widget action, {Widget? lead}) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lead ?? IconTile(icon, size: 56),
            const SizedBox(height: 12),
            Text(title, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(sub, style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: body)),
            SizedBox(width: double.infinity, child: action),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: 300.ms,
                    height: 4,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i <= step ? context.scheme.primary : cc.surfaceRaised,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                shell(
                  AppIcons.handWaving,
                  'Commit code.\nCommit to goals.',
                  'Every day is a commit. Your history is your proof. What should we call you?',
                  TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Your name'), onChanged: (_) => setState(() {})),
                  FilledButton(onPressed: name.text.trim().isEmpty ? null : next, child: const Text('Continue')),
                  lead: const CommitLogo(size: 64),
                ),
                shell(
                  AppIcons.dna,
                  "I'm becoming a…",
                  'Each task you finish is a vote for who you are becoming.',
                  Column(children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in identities.keys)
                        ChoiceChip(
                          label: Text(e),
                          selected: identity == e,
                          onSelected: (_) => setState(() {
                            identity = e;
                            skills
                              ..clear()
                              ..addAll(identities[e]!);
                          }),
                        ),
                    ]),
                    if (identity != null) ...[
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: Text('Skills to level up', style: context.text.labelLarge)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final k in {...identities[identity]!, ...defaultSkills})
                          FilterChip(
                            label: Text(k),
                            selected: skills.contains(k),
                            onSelected: (v) => setState(() => v ? skills.add(k) : skills.remove(k)),
                          ),
                      ]),
                    ],
                  ]),
                  FilledButton(onPressed: identity == null || skills.isEmpty ? null : next, child: const Text('Continue')),
                ),
                shell(
                  AppIcons.link,
                  'Link your platforms',
                  'Public usernames only — real work will tick your tasks off automatically. You can skip this.',
                  Column(children: [
                    TextField(controller: gh, autocorrect: false, decoration: const InputDecoration(labelText: 'GitHub username', prefixIcon: Icon(Icons.code))),
                    if (ghMsg != null) _result(ghMsg!),
                    const SizedBox(height: 12),
                    TextField(controller: lc, autocorrect: false, decoration: const InputDecoration(labelText: 'LeetCode username', prefixIcon: Icon(Icons.terminal))),
                    if (lcMsg != null) _result(lcMsg!),
                    const SizedBox(height: 12),
                    TextField(controller: cf, autocorrect: false, decoration: const InputDecoration(labelText: 'Codeforces handle', prefixIcon: Icon(Icons.bar_chart_rounded))),
                    if (cfMsg != null) _result(cfMsg!),
                    const SizedBox(height: 8),
                    TextButton(onPressed: next, child: const Text('Skip for now')),
                  ]),
                  FilledButton(
                    onPressed: checking ? null : (gh.text.trim().isEmpty && lc.text.trim().isEmpty && cf.text.trim().isEmpty ? next : _link),
                    child: Text(checking ? 'Checking…' : 'Link & continue'),
                  ),
                ),
                shell(
                  AppIcons.plant,
                  'Your initial commit',
                  'Start with a win. What did you learn or do today, even something tiny?',
                  Column(children: [
                    TextField(controller: task, decoration: const InputDecoration(hintText: 'e.g. Set up Commit and picked my goals'), onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    Text('We will log it as your first commit so your streak starts at day 1 — and you already have a head start on your first badge.',
                        style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
                  ]),
                  FilledButton(onPressed: task.text.trim().isEmpty ? null : _finish, child: const Text('Make my first commit')),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
