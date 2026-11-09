import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/commit_colors.dart';
import '../capture/capture_sheet.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final cs = context.scheme;
    Widget item(int i, IconData icon, IconData activeIcon, String label) {
      final active = shell.currentIndex == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              shell.goBranch(i, initialLocation: i == shell.currentIndex);
            },
            child: SizedBox(
              height: 60,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(active ? activeIcon : icon, color: active ? cs.primary : context.cc.textSecondary),
                const SizedBox(height: 2),
                Text(label,
                    style: context.text.labelSmall?.copyWith(
                        color: active ? cs.primary : context.cc.textSecondary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showCaptureSheet(context, idea: true);
        },
        child: FloatingActionButton(
          tooltip: 'Quick capture (hold for idea)',
          backgroundColor: cs.primary,
          foregroundColor: context.cc.onAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: () => showCaptureSheet(context),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: cs.surface,
        padding: EdgeInsets.zero,
        height: 64,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(children: [
          item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
          item(1, Icons.checklist_rounded, Icons.checklist_rounded, 'Tasks'),
          const SizedBox(width: 72),
          item(2, Icons.lock_outline_rounded, Icons.lock_rounded, 'Vault'),
          item(3, Icons.radar_rounded, Icons.radar_rounded, 'Skills'),
        ]),
      ),
    );
  }
}
