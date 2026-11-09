String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Calendar-day arithmetic that is safe across DST changes.
String addDays(String k, int n) {
  final d = parseDayKey(k);
  return dayKey(DateTime(d.year, d.month, d.day + n));
}

int daysBetween(String a, String b) {
  final x = parseDayKey(a), y = parseDayKey(b);
  return DateTime.utc(y.year, y.month, y.day)
      .difference(DateTime.utc(x.year, x.month, x.day))
      .inDays;
}
