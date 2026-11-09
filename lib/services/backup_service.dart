import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/day_key.dart';
import '../data/models.dart';

class BackupPreview {
  final AppState state;
  final DateTime? exportedAt;
  const BackupPreview(this.state, this.exportedAt);
  int get tasks => state.tasks.length;
  int get vault => state.wallet.length;
  int get commits => state.commits.where((c) => !c.frozen).length;
  int get friends => state.friends.length;
}

/// Account-free backup: everything on the device as one JSON file you can share
/// to Drive/email and restore later (also the way to move to a new phone).
class BackupService {
  static const _app = 'commit';

  static String encode(AppState s, DateTime now) =>
      const JsonEncoder.withIndent('  ').convert({'app': _app, 'version': 2, 'exportedAt': now.toIso8601String(), 'state': s.toJson()});

  /// Validates and decodes a backup. Throws [FormatException] with a user-facing message.
  static BackupPreview parse(String raw) {
    final Object? j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('That file is not a valid backup (not JSON).');
    }
    if (j is! Map || j['app'] != _app || j['state'] is! Map) {
      throw const FormatException('That file is not a Commit backup.');
    }
    final version = j['version'];
    if (version is! int || version > 2) {
      throw const FormatException('This backup was made by a newer version of Commit.');
    }
    try {
      final state = AppState.fromJson(Map<String, dynamic>.from(j['state'] as Map));
      return BackupPreview(state, DateTime.tryParse('${j['exportedAt']}'));
    } catch (_) {
      throw const FormatException('The backup file is damaged and could not be read.');
    }
  }

  static Future<File> write(AppState s, DateTime now) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/commit-backup-${dayKey(now)}.json');
    return f.writeAsString(encode(s, now));
  }

  static Future<void> share(File f) => SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: 'application/json')], subject: 'Commit backup', text: 'My Commit backup'),
      );
}
