import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/day_key.dart';
import '../data/models.dart';
import 'platform_provider.dart';

class GithubProvider implements PlatformProvider {
  final http.Client client;
  final DateTime Function() now;
  GithubProvider(this.client, {DateTime Function()? now}) : now = now ?? DateTime.now;

  @override
  String get id => 'github';

  Future<dynamic> _get(String path) async {
    final res = await client.get(Uri.parse('https://api.github.com$path'),
        headers: {'Accept': 'application/vnd.github+json'});
    if (res.statusCode == 404) throw PlatformException('GitHub user not found');
    if (res.statusCode == 403) throw PlatformException('GitHub rate limit hit — try again later');
    if (res.statusCode != 200) throw PlatformException('GitHub error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  @override
  Future<PlatformSnapshot> fetch(String username) async {
    final user = await _get('/users/$username');
    final repos = await _get('/users/$username/repos?per_page=100&sort=pushed') as List;
    final events = await _get('/users/$username/events/public?per_page=100') as List;
    return parse(username, Map<String, dynamic>.from(user), repos, events);
  }

  PlatformSnapshot parse(String username, Map<String, dynamic> user, List repos, List events) {
    final langs = <String, int>{};
    var stars = 0;
    for (final r in repos) {
      final l = r['language'];
      if (l != null) langs[l] = (langs[l] ?? 0) + 1;
      stars += (r['stargazers_count'] as int?) ?? 0;
    }
    final activity = <String, int>{};
    var prs = 0;
    for (final e in events) {
      final created = DateTime.tryParse(e['created_at'] ?? '')?.toLocal();
      if (created == null) continue;
      final k = dayKey(created);
      switch (e['type']) {
        case 'PushEvent':
          final n = (e['payload']?['size'] as int?) ?? (e['payload']?['commits'] as List?)?.length ?? 1;
          activity[k] = (activity[k] ?? 0) + (n < 1 ? 1 : n);
        case 'PullRequestEvent':
          activity[k] = (activity[k] ?? 0) + 1;
          if (e['payload']?['action'] == 'opened') prs++;
      }
    }
    final today = dayKey(now());
    final weekStart = addDays(today, -6);
    final week = activity.entries
        .where((e) => e.key.compareTo(weekStart) >= 0 && e.key.compareTo(today) <= 0)
        .fold<int>(0, (a, e) => a + e.value);
    return PlatformSnapshot(
      platform: 'github',
      username: username,
      fetchedAt: now(),
      activity: activity,
      breakdown: langs,
      stats: {
        'repos': (user['public_repos'] as int?) ?? repos.length,
        'followers': (user['followers'] as int?) ?? 0,
        'stars': stars,
        'weekCommits': week,
        'openedPrs': prs,
      },
    );
  }
}
