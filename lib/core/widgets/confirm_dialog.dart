import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/commit_colors.dart';
import 'widgets.dart';
import '../icons.dart';

/// Shared "are you sure?" prompt for anything destructive. Resolves to false
/// when cancelled or dismissed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  IconData icon = AppIcons.trash,
}) async {
  HapticFeedback.mediumImpact();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: IconTile(icon, color: c.scheme.error, size: 52),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.scheme.error, foregroundColor: c.scheme.onError),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
