import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/day_key.dart';
import '../data/models.dart';
import 'platform_provider.dart';

/// Uses LeetCode's unofficial GraphQL endpoint; may break without notice, so
/// failures are caught per-platform and the last good snapshot stays cached.
class LeetcodeProvider implements PlatformProvider {
  final http.Client client;
  final DateTime Function() now;
  LeetcodeProvider(this.client, {DateTime Function()? now}) : now = now ?? DateTime.now;

  @override
  String get id => 'leetcode';

  static const _query = r'''
query u($username: String!) {
  matchedUser(username: $username) {
    submitStatsGlobal { acSubmissionNum { difficulty count } }
    tagProblemCounts {
      advanced { tagName problemsSolved }
      intermediate { tagName problemsSolved }
      fundamental { tagName problemsSolved }
    }
    userCalendar { streak submissionCalendar }
  }
  userContestRanking(username: $username) { rating }
  recentAcSubmissionList(username: $username, limit: 50) { title timestamp }
}''';

  @override
  Future<PlatformSnapshot> fetch(String username) async {
    final res = await client.post(
      Uri.parse('https://leetcode.com/graphql'),
      headers: {'Content-Type': 'application/json', 'Referer': 'https://leetcode.com'},
      body: jsonEncode({'query': _query, 'variables': {'username': username}}),
    );
    if (res.statusCode != 200) throw PlatformException('LeetCode error ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return parse(username, body);
  }

  PlatformSnapshot parse(String username, Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>?;
    final user = data?['matchedUser'] as Map<String, dynamic>?;
    if (user == null) throw PlatformException('LeetCode user not found');

    final stats = <String, num>{};
    for (final e in (user['submitStatsGlobal']?['acSubmissionNum'] as List? ?? const [])) {
      final c = e['count'] as int;
      switch (e['difficulty']) {
        case 'All':
          stats['solved'] = c;
        case 'Easy':
          stats['easy'] = c;
        case 'Medium':
          stats['medium'] = c;
        case 'Hard':
          stats['hard'] = c;
      }
    }
    final rating = data?['userContestRanking']?['rating'];
    if (rating is num) stats['rating'] = rating.round();
    stats['streak'] = (user['userCalendar']?['streak'] as int?) ?? 0;

    final tags = <String, int>{};
    final tpc = user['tagProblemCounts'] as Map<String, dynamic>? ?? const {};
    for (final level in ['fundamental', 'intermediate', 'advanced']) {
      for (final t in (tpc[level] as List? ?? const [])) {
        tags[t['tagName']] = (tags[t['tagName']] ?? 0) + (t['problemsSolved'] as int);
      }
    }

    // Distinct accepted problems per local day from recent submissions.
    final perDay = <String, Set<String>>{};
    for (final s in (data?['recentAcSubmissionList'] as List? ?? const [])) {
      final ts = int.tryParse('${s['timestamp']}');
      if (ts == null) continue;
      final k = dayKey(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
      (perDay[k] ??= {}).add(s['title'] as String);
    }
    final activity = {for (final e in perDay.entries) e.key: e.value.length};

    // Older history from the submission calendar (UTC day buckets).
    final cal = user['userCalendar']?['submissionCalendar'];
    if (cal is String && cal.isNotEmpty) {
      final m = jsonDecode(cal) as Map<String, dynamic>;
      for (final e in m.entries) {
        final ts = int.tryParse(e.key);
        if (ts == null) continue;
        final k = dayKey(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
        activity.putIfAbsent(k, () => (e.value as num).toInt());
      }
    }
    final today = dayKey(now());
    stats['weekSolved'] = activity.entries
        .where((e) => e.key.compareTo(addDays(today, -6)) >= 0 && e.key.compareTo(today) <= 0)
        .fold<int>(0, (a, e) => a + e.value);

    return PlatformSnapshot(
      platform: 'leetcode',
      username: username,
      fetchedAt: now(),
      activity: activity,
      stats: stats,
      breakdown: tags,
    );
  }
}
