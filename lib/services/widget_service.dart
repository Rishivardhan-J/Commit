import 'dart:io';
import 'package:home_widget/home_widget.dart';
import '../data/models.dart';
import '../engine/streak_engine.dart';

/// Pushes streak/progress to the Android home-screen widget. Best effort: never throws.
class WidgetService {
  static String? _last;

  static Future<void> update(AppState s, String today) async {
    if (!Platform.isAndroid || !s.onboarded) return;
    try {
      final streak = computeStreak(s, today);
      final staged = s.tasks.where((t) => t.stagedFor == today || (t.done && t.doneDay == today)).toList();
      final done = staged.where((t) => t.done).length;
      final today1 = staged.isEmpty ? 'Nothing staged yet' : '$done of ${staged.length} done today';
      final cta = streak.committedToday
          ? 'Day committed'
          : done > 0
              ? 'Tap to commit the day'
              : (staged.isEmpty ? 'Stage today' : 'Finish one task');
      final key = '${streak.current}|$today1|$cta';
      if (key == _last) return; // avoid redundant widget refreshes
      _last = key;
      await HomeWidget.saveWidgetData<String>('streak', '${streak.current}');
      await HomeWidget.saveWidgetData<String>('today', today1);
      await HomeWidget.saveWidgetData<String>('cta', cta);
      await HomeWidget.updateWidget(qualifiedAndroidName: 'dev.commitapp.commit.CommitWidgetProvider');
    } catch (_) {}
  }
}
