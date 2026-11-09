import 'dart:math';
import '../data/models.dart';

/// Unified Coding Score, 0..1000. Log-scaled so early effort moves it visibly
/// and nobody maxes out by grinding a single platform.
int codingScore(AppState s, int streak) {
  final lc = s.snapshots['leetcode'];
  final gh = s.snapshots['github'];
  final easy = lc?.stats['easy'] ?? 0;
  final med = lc?.stats['medium'] ?? 0;
  final hard = lc?.stats['hard'] ?? 0;
  final rating = lc?.stats['rating'] ?? 0;
  final weighted = easy + 3 * med + 5 * hard;
  final ghAct = gh == null ? 0 : gh.activity.values.fold<int>(0, (a, b) => a + b);

  double part(num v, num scale, double max) => max * min(1.0, log(1 + v / scale) / log(1 + 10));

  final lcPart = part(weighted, 30, 330); // 30 weighted ≈ small, 300 ≈ full
  final ratingPart = rating <= 0 ? 0.0 : min(1.0, max(0, rating - 1200) / 1300) * 120;
  final ghPart = part(ghAct, 10, 220);
  final streakPart = part(streak, 3, 150);
  final taskPart = part(s.tasks.where((t) => t.done).length, 5, 180);
  return (lcPart + ratingPart + ghPart + streakPart + taskPart).round().clamp(0, 1000);
}
