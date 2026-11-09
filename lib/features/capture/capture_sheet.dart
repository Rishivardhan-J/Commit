import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/toast.dart';
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
  final _stt = SpeechToText();
  bool listening = false;
  double _level = 0;

  Future<void> _toggleMic() async {
    if (listening) {
      await _stt.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final ok = await _stt.initialize(
      onStatus: (st) {
        if ((st == 'done' || st == 'notListening') && mounted) setState(() => listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!ok) {
      AppToast.show('Voice input isn\'t available — check the microphone permission', kind: ToastKind.warn, icon: Icons.mic_off_rounded);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => listening = true);
    await _stt.listen(
      onResult: (r) {
        title.text = r.recognizedWords;
        title.selection = TextSelection.collapsed(offset: title.text.length);
        if (mounted) setState(() {});
      },
      onSoundLevelChange: (l) {
        if (mounted) setState(() => _level = ((l + 2) / 12).clamp(0.0, 1.0));
      },
      listenOptions: SpeechListenOptions(listenFor: const Duration(seconds: 30), pauseFor: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _stt.cancel();
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
    Navigator.pop(context);
    AppToast.show(
      idea ? 'Idea saved to your vault' : stageToday ? 'Staged for today · ${difficulty * 10} xp on offer' : 'Task added to backlog',
      icon: idea ? Icons.lightbulb_rounded : Icons.add_task_rounded,
    );
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
            decoration: InputDecoration(
              hintText: listening ? 'Listening…' : (idea ? 'What is the idea?' : 'What will you ship?'),
              suffixIcon: IconButton(
                tooltip: listening ? 'Stop dictation' : 'Dictate',
                onPressed: _toggleMic,
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: EdgeInsets.all(listening ? 4 + 6 * _level : 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: listening ? context.scheme.error.withValues(alpha: 0.18) : Colors.transparent,
                  ),
                  child: Icon(listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: listening ? context.scheme.error : null),
                ),
              ),
            ),
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
