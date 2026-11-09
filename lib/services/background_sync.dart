import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../data/models.dart';
import '../platforms/sync_service.dart';

const _task = 'commit.periodicSync';
const _stateKey = 'commit_state_v1';

/// Runs in a background isolate (Android only): refresh platform data so tasks
/// are already ticked off when the user opens the app.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((taskName, input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_stateKey);
      if (raw == null) return true;
      final s = AppState.decode(raw);
      if (!s.onboarded) return true;
      final client = http.Client();
      final next = await syncState(s, client, DateTime.now);
      client.close();
      // Only snapshots/auto-ticks change; re-read to avoid clobbering newer foreground edits.
      await prefs.reload();
      final fresh = AppState.decode(prefs.getString(_stateKey) ?? raw);
      await prefs.setString(
          _stateKey, fresh.copyWith(snapshots: next.snapshots, syncErrors: next.syncErrors, tasks: _mergeAuto(fresh, next)).encode());
      return true;
    } catch (_) {
      return false; // retry later
    }
  });
}

List<Task> _mergeAuto(AppState fresh, AppState next) {
  final auto = {for (final t in next.tasks.where((t) => t.auto && t.done)) t.id: t};
  return [for (final t in fresh.tasks) (!t.done && auto.containsKey(t.id)) ? auto[t.id]! : t];
}

Future<void> scheduleBackgroundSync() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 3),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (_) {}
}
