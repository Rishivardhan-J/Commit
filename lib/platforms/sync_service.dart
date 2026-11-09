import 'package:http/http.dart' as http;
import '../core/utils/day_key.dart';
import '../data/models.dart';
import '../engine/autocomplete_engine.dart';
import 'github_provider.dart';
import 'leetcode_provider.dart';
import 'platform_provider.dart';

/// Pulls every linked platform and ticks satisfied tasks. Each platform fails
/// independently and keeps its last good snapshot. Pure (no Riverpod) so it can
/// also run from the background isolate.
Future<AppState> syncState(AppState s, http.Client client, DateTime Function() now) async {
  final jobs = <PlatformProvider, String>{
    if (s.githubUser.isNotEmpty) GithubProvider(client, now: now): s.githubUser,
    if (s.leetcodeUser.isNotEmpty) LeetcodeProvider(client, now: now): s.leetcodeUser,
  };
  var out = s;
  for (final e in jobs.entries) {
    try {
      final snap = await e.key.fetch(e.value);
      out = out.copyWith(
        snapshots: {...out.snapshots, e.key.id: snap},
        syncErrors: {...out.syncErrors}..remove(e.key.id),
      );
    } on PlatformException catch (x) {
      out = out.copyWith(syncErrors: {...out.syncErrors, e.key.id: x.message});
    } catch (_) {
      out = out.copyWith(syncErrors: {...out.syncErrors, e.key.id: 'Could not reach ${e.key.id}'});
    }
  }
  final today = dayKey(now());
  final hits = satisfiedTasks(out, today).map((t) => t.id).toSet();
  if (hits.isNotEmpty) {
    out = out.copyWith(tasks: [
      for (final t in out.tasks) hits.contains(t.id) ? t.copyWith(done: true, auto: true, doneDay: today) : t,
    ]);
  }
  return out;
}
