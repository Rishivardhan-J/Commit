import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/day_key.dart';
import '../data/models.dart';
import 'platform_provider.dart';

/// Codeforces has an official public API, so this is the most reliable provider.
class CodeforcesProvider implements PlatformProvider {
  final http.Client client;
  final DateTime Function() now;
  CodeforcesProvider(this.client, {DateTime Function()? now}) : now = now ?? DateTime.now;

  @override
  String get id => 'codeforces';

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await client.get(Uri.parse('https://codeforces.com/api/$path'));
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (body != null && body['status'] == 'FAILED') {
      final c = '${body['comment'] ?? ''}';
      throw PlatformException(c.contains('not found') ? 'Codeforces user not found' : 'Codeforces: $c');
    }
    if (res.statusCode != 200 || body == null) throw PlatformException('Codeforces error ${res.statusCode}');
    return body;
  }

  @override
  Future<PlatformSnapshot> fetch(String username) async {
    final info = await _get('user.info?handles=$username');
    final status = await _get('user.status?handle=$username&from=1&count=1000');
    return parse(username, info, status);
  }

  PlatformSnapshot parse(String username, Map<String, dynamic> info, Map<String, dynamic> status) {
    final user = ((info['result'] as List?) ?? const []).isEmpty ? null : (info['result'] as List).first as Map<String, dynamic>;
    if (user == null) throw PlatformException('Codeforces user not found');

    final solved = <String>{};
    final perDay = <String, Set<String>>{};
    final tagSolved = <String, Set<String>>{};
    for (final s in (status['result'] as List? ?? const [])) {
      if (s['verdict'] != 'OK') continue;
      final p = s['problem'] as Map<String, dynamic>;
      final key = '${p['contestId']}${p['index']}';
      solved.add(key);
      final ts = (s['creationTimeSeconds'] as num).toInt();
      final day = dayKey(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
      (perDay[day] ??= {}).add(key);
      for (final t in (p['tags'] as List? ?? const [])) {
        (tagSolved[t as String] ??= {}).add(key);
      }
    }
    final activity = {for (final e in perDay.entries) e.key: e.value.length};
    final today = dayKey(now());
    final weekStart = addDays(today, -6);
    final week = activity.entries
        .where((e) => e.key.compareTo(weekStart) >= 0 && e.key.compareTo(today) <= 0)
        .fold<int>(0, (a, e) => a + e.value);

    return PlatformSnapshot(
      platform: 'codeforces',
      username: username,
      fetchedAt: now(),
      activity: activity,
      breakdown: {for (final e in tagSolved.entries) e.key: e.value.length},
      stats: {
        'solved': solved.length,
        'rating': (user['rating'] as num?) ?? 0,
        'maxRating': (user['maxRating'] as num?) ?? 0,
        'weekSolved': week,
      },
    );
  }
}
