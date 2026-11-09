import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';

class _Step {
  final String title, skill;
  final TaskType type;
  final int difficulty;
  final AutoRule? rule;
  const _Step(this.title, this.skill, this.type, this.difficulty, [this.rule]);
}

class _Roadmap {
  final String name, emoji, blurb;
  final List<List<_Step>> weeks;
  const _Roadmap(this.name, this.emoji, this.blurb, this.weeks);
}

const _roadmaps = [
  _Roadmap('Placement prep', '🎯', 'DSA fundamentals, a project and interview practice.', [
    [
      _Step('Solve 3 array problems', 'Arrays', TaskType.dsa, 2, AutoRule('lc.solved', 3)),
      _Step('Revise hashing patterns', 'Hashing', TaskType.learning, 1),
      _Step('Push a small commit to a project', 'Projects', TaskType.project, 1, AutoRule('gh.commits', 1)),
    ],
    [
      _Step('Solve 3 tree problems', 'Trees', TaskType.dsa, 2, AutoRule('lc.solved', 3)),
      _Step('Solve 2 binary search problems', 'Binary Search', TaskType.dsa, 2, AutoRule('lc.solved', 2)),
      _Step('Write a STAR story for one project', 'Communication', TaskType.learning, 1),
    ],
    [
      _Step('Solve 3 graph problems', 'Graphs', TaskType.dsa, 3, AutoRule('lc.solved', 3)),
      _Step('Solve 2 DP problems', 'Dynamic Programming', TaskType.dsa, 3, AutoRule('lc.solved', 2)),
      _Step('Mock interview with a friend', 'Communication', TaskType.learning, 2),
    ],
  ]),
  _Roadmap('Web development', '🌐', 'From HTML/CSS to a deployed full-stack app.', [
    [
      _Step('Build a responsive landing page', 'CSS', TaskType.project, 2, AutoRule('gh.commits', 1)),
      _Step('Learn JS array methods', 'JavaScript', TaskType.learning, 1),
    ],
    [
      _Step('Build a React component with state', 'React', TaskType.project, 2, AutoRule('gh.commits', 1)),
      _Step('Read the React hooks docs', 'React', TaskType.learning, 1),
    ],
    [
      _Step('Add a REST API endpoint', 'Backend', TaskType.project, 2, AutoRule('gh.commits', 1)),
      _Step('Deploy the app', 'DevOps', TaskType.project, 3),
    ],
  ]),
  _Roadmap('Machine learning', '🧠', 'Math basics to a trained, evaluated model.', [
    [
      _Step('Revise linear algebra: vectors & matrices', 'Math', TaskType.learning, 1),
      _Step('Clean a dataset with pandas', 'Python', TaskType.project, 2),
    ],
    [
      _Step('Train a baseline classifier', 'Machine Learning', TaskType.project, 2, AutoRule('gh.commits', 1)),
      _Step('Study overfitting and validation', 'Machine Learning', TaskType.learning, 2),
    ],
    [
      _Step('Write up results in a notebook', 'Machine Learning', TaskType.project, 2, AutoRule('gh.commits', 1)),
    ],
  ]),
  _Roadmap('GSoC / open source', '🌍', 'Find a project, land a first PR.', [
    [
      _Step('Shortlist 3 orgs and read their contribution guides', 'Open Source', TaskType.openSource, 1),
      _Step('Set up one project locally', 'Open Source', TaskType.openSource, 2),
    ],
    [
      _Step('Pick a good-first-issue and comment on it', 'Open Source', TaskType.openSource, 1),
      _Step('Open your first pull request', 'Open Source', TaskType.openSource, 3, AutoRule('gh.commits', 1)),
    ],
    [
      _Step('Respond to review feedback', 'Communication', TaskType.openSource, 2),
      _Step('Draft your GSoC proposal outline', 'Open Source', TaskType.openSource, 2),
    ],
  ]),
];

/// Pick a goal → add a suggested weekly plan to your backlog (fully editable afterwards).
class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    return Scaffold(
      appBar: AppBar(title: const Text('Goal roadmaps')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        Text('Choose a goal and add a week of tasks to your backlog. Stage the ones you want each morning.',
            style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)),
        const SizedBox(height: 12),
        for (final r in _roadmaps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.emoji}  ${r.name}', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(r.blurb, style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var w = 0; w < r.weeks.length; w++)
                    OutlinedButton(
                      onPressed: () {
                        final n = ref.read(appProvider.notifier);
                        final existing = ref.read(appProvider).tasks.map((t) => t.title).toSet();
                        var added = 0;
                        for (final s in r.weeks[w]) {
                          if (existing.contains(s.title)) continue;
                          n.addTask(title: s.title, skill: s.skill, type: s.type, difficulty: s.difficulty, rule: s.rule, stageToday: false);
                          added++;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(added == 0 ? 'Week ${w + 1} is already in your backlog' : 'Added $added tasks to your backlog'),
                        ));
                        if (added > 0) context.go('/tasks');
                      },
                      child: Text('Add week ${w + 1}'),
                    ),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
