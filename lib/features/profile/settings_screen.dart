import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../services/notification_service.dart';
import '../vault/vault_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final gh = TextEditingController(text: ref.read(appProvider).githubUser);
  late final lc = TextEditingController(text: ref.read(appProvider).leetcodeUser);
  bool syncing = false;

  @override
  void dispose() {
    gh.dispose();
    lc.dispose();
    super.dispose();
  }

  Future<void> _saveAccounts() async {
    final n = ref.read(appProvider.notifier);
    n.updateSettings(githubUser: gh.text.trim(), leetcodeUser: lc.text.trim());
    setState(() => syncing = true);
    await n.sync(force: true);
    if (mounted) setState(() => syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final prefs = ref.read(prefsProvider);
    final today = ref.watch(todayProvider);
    final cc = context.cc;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        const SectionTitle('Linked accounts'),
        CCard(
          child: Column(children: [
            TextField(controller: gh, autocorrect: false, decoration: const InputDecoration(labelText: 'GitHub username', prefixIcon: Icon(Icons.code))),
            const SizedBox(height: 10),
            TextField(controller: lc, autocorrect: false, decoration: const InputDecoration(labelText: 'LeetCode username', prefixIcon: Icon(Icons.terminal))),
            const SizedBox(height: 6),
            Text('Only public profile data is read. Commit never asks for a password.',
                style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: syncing ? null : _saveAccounts, child: Text(syncing ? 'Syncing…' : 'Save & sync')),
            ),
            for (final e in s.syncErrors.entries)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('${e.key}: ${e.value}', style: TextStyle(color: cc.warning))),
          ]),
        ),
        const SectionTitle('Appearance'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'system', label: Text('System')),
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'dark', label: Text('Dark')),
          ],
          selected: {s.themeMode},
          onSelectionChanged: (v) => n.updateSettings(themeMode: v.first),
        ),
        const SectionTitle('Habit'),
        CCard(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: [
            SwitchListTile(
              title: const Text('Evening reminder'),
              subtitle: const Text('Max one gentle nudge a day. No guilt trips.'),
              value: s.notifications,
              onChanged: (v) async {
                n.updateSettings(notifications: v);
                if (v) {
                  await NotificationService.instance.requestPermission();
                  n.replanReminder();
                } else {
                  await NotificationService.instance.cancelAll();
                }
              },
            ),
            ListTile(
              title: const Text('Reminder time'),
              subtitle: Text('${s.reminderHour.toString().padLeft(2, '0')}:00 every evening'),
              enabled: s.notifications,
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.reminderHour, minute: 0));
                if (t != null) {
                  n.updateSettings(reminderHour: t.hour);
                  n.replanReminder();
                }
              },
            ),
            ListTile(
              title: const Text('Plan a rest day for tomorrow'),
              subtitle: const Text('Rest days keep your streak. Recovery is part of the work.'),
              trailing: s.restDays.contains(addDays(today, 1)) ? Icon(Icons.check_circle, color: cc.success) : null,
              onTap: () {
                n.scheduleRestDay(addDays(today, 1));
                HapticFeedback.selectionClick();
              },
            ),
            SwitchListTile(
              title: const Text('Lock vault with biometrics'),
              value: prefs.getBool(vaultLockKey) ?? false,
              onChanged: (v) async {
                await prefs.setBool(vaultLockKey, v);
                setState(() {});
              },
            ),
          ]),
        ),
        const SectionTitle('Data'),
        CCard(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            title: Text('Reset all data', style: TextStyle(color: context.scheme.error)),
            subtitle: const Text('Deletes tasks, vault, streaks and XP from this device.'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset everything?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (ok == true) n.resetAll();
            },
          ),
        ),
      ]),
    );
  }
}
