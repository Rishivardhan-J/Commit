import 'dart:convert';
import 'package:commit/platforms/codeforces_provider.dart';
import 'package:commit/platforms/github_provider.dart';
import 'package:commit/platforms/leetcode_provider.dart';
import 'package:commit/platforms/platform_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final now = DateTime(2026, 11, 9, 12);

  test('leetcode parses solved counts, tags and activity', () async {
    final ts = DateTime(2026, 11, 9, 9).millisecondsSinceEpoch ~/ 1000;
    final body = {
      'data': {
        'matchedUser': {
          'submitStatsGlobal': {
            'acSubmissionNum': [
              {'difficulty': 'All', 'count': 120},
              {'difficulty': 'Easy', 'count': 70},
              {'difficulty': 'Medium', 'count': 40},
              {'difficulty': 'Hard', 'count': 10},
            ]
          },
          'tagProblemCounts': {
            'fundamental': [{'tagName': 'Array', 'problemsSolved': 60}],
            'intermediate': [{'tagName': 'Graph', 'problemsSolved': 4}],
            'advanced': [],
          },
          'userCalendar': {'streak': 5, 'submissionCalendar': '{}'},
        },
        'userContestRanking': {'rating': 1650.4},
        'recentAcSubmissionList': [
          {'title': 'Two Sum', 'timestamp': '$ts'},
          {'title': 'Two Sum', 'timestamp': '$ts'},
          {'title': 'Course Schedule', 'timestamp': '$ts'},
        ],
      }
    };
    final client = MockClient((_) async => http.Response(jsonEncode(body), 200));
    final snap = await LeetcodeProvider(client, now: () => now).fetch('u');
    expect(snap.stats['solved'], 120);
    expect(snap.stats['rating'], 1650);
    expect(snap.breakdown['Graph'], 4);
    expect(snap.activity['2026-11-09'], 2); // distinct problems
  });

  test('leetcode unknown user throws friendly error', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'data': {'matchedUser': null}}), 200));
    expect(LeetcodeProvider(client, now: () => now).fetch('nobody'), throwsA(isA<PlatformException>()));
  });

  test('github parses languages and recent push commits', () async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/events/public')) {
        return http.Response(
            jsonEncode([
              {'type': 'PushEvent', 'created_at': DateTime(2026, 11, 9, 10).toUtc().toIso8601String(), 'payload': {'size': 3}},
              {'type': 'PullRequestEvent', 'created_at': DateTime(2026, 11, 8, 10).toUtc().toIso8601String(), 'payload': {'action': 'opened'}},
            ]),
            200);
      }
      if (r.url.path.contains('/repos')) {
        return http.Response(jsonEncode([{'language': 'Dart', 'stargazers_count': 2}, {'language': 'Dart', 'stargazers_count': 1}]), 200);
      }
      return http.Response(jsonEncode({'public_repos': 2, 'followers': 1}), 200);
    });
    final snap = await GithubProvider(client, now: () => now).fetch('u');
    expect(snap.breakdown['Dart'], 2);
    expect(snap.stats['stars'], 3);
    expect(snap.stats['weekCommits'], 4);
    expect(snap.stats['openedPrs'], 1);
  });

  test('github 404 maps to a friendly error', () async {
    final client = MockClient((_) async => http.Response('', 404));
    expect(GithubProvider(client).fetch('x'), throwsA(isA<PlatformException>()));
  });

  test('codeforces parses rating, distinct solves, tags and activity', () async {
    final ts = DateTime(2026, 11, 9, 9).millisecondsSinceEpoch ~/ 1000;
    Map<String, dynamic> sub(String v, int c, String i, List<String> tags) => {
          'verdict': v,
          'creationTimeSeconds': ts,
          'problem': {'contestId': c, 'index': i, 'tags': tags},
        };
    final client = MockClient((r) async {
      if (r.url.path.endsWith('user.info')) {
        return http.Response(jsonEncode({'status': 'OK', 'result': [{'rating': 1450, 'maxRating': 1500}]}), 200);
      }
      return http.Response(
          jsonEncode({
            'status': 'OK',
            'result': [
              sub('OK', 1, 'A', ['dp', 'math']),
              sub('OK', 1, 'A', ['dp', 'math']), // duplicate accept
              sub('WRONG_ANSWER', 2, 'B', ['graphs']),
              sub('OK', 3, 'C', ['graphs']),
            ]
          }),
          200);
    });
    final snap = await CodeforcesProvider(client, now: () => now).fetch('tourist');
    expect(snap.stats['solved'], 2);
    expect(snap.stats['rating'], 1450);
    expect(snap.breakdown['dp'], 1);
    expect(snap.breakdown['graphs'], 1);
    expect(snap.activity['2026-11-09'], 2);
  });

  test('codeforces unknown handle gives a friendly error', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'status': 'FAILED', 'comment': 'handles: User with handle zzz not found'}), 400));
    expect(CodeforcesProvider(client).fetch('zzz'), throwsA(isA<PlatformException>()));
  });
}
