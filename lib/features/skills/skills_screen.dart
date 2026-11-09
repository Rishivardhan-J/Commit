import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../engine/xp_engine.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final cc = context.cc;
    final names = {...s.focusSkills, ...s.skillXp.keys}.toList();
    names.sort((a, b) => (s.skillXp[b] ?? 0).compareTo(s.skillXp[a] ?? 0));
    final overall = levelFor(s.totalXp);

    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        CCard(
          child: Row(children: [
            LevelRing(progress: overall.progress, level: overall.level, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.identity.isEmpty ? 'Overall level' : "I'm becoming a ${s.identity}",
                    style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('${s.totalXp} xp · ${overall.remaining} to Lv ${overall.level + 1}',
                    style: AppTheme.mono(context, size: 12, color: cc.textSecondary)),
                Text('Every completed task is a vote for who you are becoming.',
                    style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
              ]),
            ),
          ]),
        ),
        if (names.length >= 3) ...[
          const SectionTitle('Radar'),
          CCard(
            child: SizedBox(
              height: 240,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
                  radarBorderData: BorderSide(color: cc.border),
                  gridBorderData: BorderSide(color: cc.border),
                  tickBorderData: BorderSide(color: cc.border),
                  titleTextStyle: TextStyle(color: cc.textSecondary, fontSize: 11),
                  getTitle: (i, _) => RadarChartTitle(text: names.take(6).toList()[i]),
                  dataSets: [
                    RadarDataSet(
                      fillColor: context.scheme.primary.withValues(alpha: 0.25),
                      borderColor: context.scheme.primary,
                      entryRadius: 3,
                      borderWidth: 2,
                      dataEntries: [
                        for (final k in names.take(6)) RadarEntry(value: skillLevelFor(s.skillXp[k] ?? 0).level.toDouble()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SectionTitle('Levels'),
        if (names.isEmpty)
          const CCard(child: EmptyState(emoji: '🌱', title: 'No skills yet', subtitle: 'Complete a tagged task and commit the day to start levelling up.'))
        else
          CCard(
            child: Column(children: [
              for (final k in names)
                Builder(builder: (_) {
                  final xp = s.skillXp[k] ?? 0;
                  final l = skillLevelFor(xp);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      LevelRing(progress: l.progress, level: l.level, size: 44, color: cc.warning),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${l.remaining} xp to $k Lv ${l.level + 1}${(s.focusMinutes[k] ?? 0) > 0 ? ' · ${s.focusMinutes[k]} min focused' : ''}',
                              style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
                        ]),
                      ),
                      Text('$xp xp', style: AppTheme.mono(context, size: 12, color: cc.warning)),
                    ]),
                  );
                }),
            ]),
          ),
      ]),
    );
  }
}
