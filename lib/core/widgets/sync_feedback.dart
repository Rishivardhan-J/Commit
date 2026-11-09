import 'package:flutter/material.dart' show Icons;
import '../../data/app_store.dart';
import 'toast.dart';

/// Turns a [SyncReport] into one toast. [manual] syncs (settings, pull-to-refresh)
/// always report; silent background-on-open syncs only speak up when a task was
/// auto-completed or something failed.
void reportSync(SyncReport r, {required bool manual}) {
  final ci = r.autoCompleted.isEmpty
      ? null
      : r.autoCompleted.length == 1
          ? 'CI passed: ${r.autoCompleted.first.title} (+${r.autoCompleted.first.xp} xp)'
          : 'CI passed: ${r.autoCompleted.length} tasks ticked automatically';

  if (r.noAccounts) {
    if (manual) {
      AppToast.show('Link GitHub or LeetCode first to sync', kind: ToastKind.info);
    }
    return;
  }
  final lines = <String>[
    for (final x in r.results)
      if (manual || !x.ok) '${x.label} · ${x.message}${x.ok ? '' : ' — showing cached data'}',
    ?ci,
  ];
  if (lines.isEmpty) return;
  AppToast.show(
    lines.join('\n'),
    kind: r.anyFailed ? ToastKind.warn : ToastKind.success,
    icon: r.anyFailed ? null : Icons.sync_rounded,
  );
}
