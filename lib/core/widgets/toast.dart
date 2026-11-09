import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/commit_colors.dart';

enum ToastKind { success, info, warn, error }

final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// One place for user feedback. Needs no BuildContext, so it survives route
/// changes, and always replaces the current toast so messages never queue up.
class AppToast {
  AppToast._();

  static void show(
    String message, {
    ToastKind kind = ToastKind.success,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = messengerKey.currentState;
    final ctx = messengerKey.currentContext;
    if (messenger == null || ctx == null) return;
    final cc = ctx.cc;
    final (color, defaultIcon) = switch (kind) {
      ToastKind.success => (cc.success, Icons.check_circle_rounded),
      ToastKind.info => (cc.info, Icons.info_rounded),
      ToastKind.warn => (cc.warning, Icons.warning_amber_rounded),
      ToastKind.error => (ctx.scheme.error, Icons.error_rounded),
    };
    kind == ToastKind.error ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    final hasAction = actionLabel != null && onAction != null;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        // Keeps the toast clear of the docked FAB and bottom bar.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: ctx.scheme.surface,
        elevation: 6,
        duration: Duration(milliseconds: hasAction ? 4500 : 2800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        content: Row(children: [
          Icon(icon ?? defaultIcon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTheme.bodyOn(ctx))),
        ]),
        action: hasAction
            ? SnackBarAction(label: actionLabel, textColor: ctx.scheme.primary, onPressed: onAction)
            : null,
      ));
  }
}
