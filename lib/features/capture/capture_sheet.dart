import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/commit_colors.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';

const defaultSkills = [
  'Arrays', 'Graphs', 'Dynamic Programming', 'Trees', 'Flutter', 'React',
  'System Design', 'Python', 'Machine Learning', 'Open Source',
];

Future<void> showCaptureSheet(BuildContext context, {bool idea = false}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CaptureSheet(startAsIdea: idea),
    );

/// 5-second capture: keyboard is up the moment the sheet opens.
class CaptureSheet extends ConsumerStatefulWidget {
  final bool startAsIdea;
  const CaptureSheet({super.key, this.startAsIdea = false});

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  late bool idea = widget.startAsIdea;
  final title = TextEditingController();
  final body = TextEditingController();
  TaskType type = TaskType.dsa;
  String? skill;
  int difficulty = 1;
  bool stageToday = true;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  void save() {
    final t = title.text.trim();
    if (t.isEmpty) return;
    final n = ref.read(appProvider.notifier);
    if (idea) {
      n.addWallet(WalletItem(id: '', kind: WalletKind.idea, title: t, body: body.text.trim()));
    } else {
      final skills = ref.read(appProvider).focusSkills;
      n.addTask(
        title: t,
        type: type,
        skill: skill ?? (skills.isNotEmpty ? skills.first : 'General'),
        difficulty: difficulty,
        stageToday: stageToday,
      );
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(idea ? 'Idea saved to your vault 💡' : stageToday ? 'Staged for today' : 'Task added'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final skills = {...ref.watch(appProvider).focusSkills, ...defaultSkills}.toList();
    final selected = skill ?? skills.first;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Task'), icon: Icon(Icons.check_circle_outline)),
              ButtonSegment(value: true, label: Text('Idea'), icon: Icon(Icons.lightbulb_outline)),
            ],
            selected: {idea},
            onSelectionChanged: (s) => setState(() => idea = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            autofocus: true,
            textInputAction: idea ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => idea ? null : save(),
            decoration: InputDecoration(hintText: idea ? 'What is the idea?' : 'What will you ship?'),
          ),
          if (idea) ...[
            const SizedBox(height: 10),
            TextField(controller: body, maxLines: 3, decoration: const InputDecoration(hintText: 'Details (optional)')),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in TaskType.values)
                ChoiceChip(label: Text(t.label), selected: type == t, onSelected: (_) => setState(() => type = t)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final k in skills)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k),
                      selected: selected == k,
                      onSelected: (_) => setState(() => skill = k),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Effort', style: context.text.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 1; i <= 3; i++)
                ChoiceChip(
                  label: Text(['Light · 10xp', 'Solid · 20xp', 'Deep · 30xp'][i - 1]),
                  selected: difficulty == i,
                  onSelected: (_) => setState(() => difficulty = i),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stage for today'),
              value: stageToday,
              onChanged: (v) => setState(() => stageToday = v),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: Text(idea ? 'Save idea' : 'Add task'))),
        ]),
      ),
    );
  }
}
