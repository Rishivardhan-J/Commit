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

    Widget item(int i, IconData icon, IconData activeIcon, String label) => Expanded(
          child: _NavItem(
            icon: icon,
            activeIcon: activeIcon,
            label: label,
            active: shell.currentIndex == i,
            onTap: () {
              HapticFeedback.selectionClick();
              shell.goBranch(i, initialLocation: i == shell.currentIndex);
            },
          ),
        );

    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _PressScale(
        child: GestureDetector(
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

/// Bottom-bar item: pill indicator, icon scale and label colour all tween together.
class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = context.scheme.primary;
    final idle = context.cc.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: active ? 1 : 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final color = Color.lerp(idle, primary, t)!;
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  height: 30,
                  width: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.16 * t),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Transform.scale(
                    scale: 1 + 0.12 * t,
                    child: Icon(active ? activeIcon : icon, color: color, size: 24),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: context.text.labelSmall?.copyWith(
                        color: color, fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  const _PressScale({required this.child});
  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => down = true),
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(
          scale: down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Keeps every tab's navigator alive (state and scroll position survive, like
/// indexedStack) but fades + lifts the newly selected tab in.
class AnimatedBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  @override
  Widget build(BuildContext context) => Stack(children: [
        for (var i = 0; i < children.length; i++)
          _BranchFade(active: i == currentIndex, child: RepaintBoundary(child: children[i])),
      ]);
}

class _BranchFade extends StatefulWidget {
  final bool active;
  final Widget child;
  const _BranchFade({required this.active, required this.child});
  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.active ? 1 : 0,
  );
  late final curved = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_BranchFade old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) controller.forward(from: 0);
    if (!widget.active && old.active) controller.value = 0;
  }

  @override
  void dispose() {
    curved.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
        offstage: !widget.active,
        child: TickerMode(
          enabled: widget.active,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(curved),
              child: widget.child,
            ),
          ),
        ),
      );
}
