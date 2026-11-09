import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/sync_feedback.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../services/backup_service.dart';
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
  late final cf = TextEditingController(text: ref.read(appProvider).codeforcesUser);
  bool syncing = false;

  @override
  void dispose() {
    gh.dispose();
    lc.dispose();
    cf.dispose();
    super.dispose();
  }

  Future<void> _saveAccounts() async {
    final n = ref.read(appProvider.notifier);
    n.updateSettings(githubUser: gh.text.trim(), leetcodeUser: lc.text.trim(), codeforcesUser: cf.text.trim());
    setState(() => syncing = true);
    final report = await n.sync(force: true);
    if (mounted) setState(() => syncing = false);
    reportSync(report, manual: true);
  }

  Future<void> _export() async {
    try {
      final f = await BackupService.write(ref.read(appProvider), ref.read(clockProvider)());
      await BackupService.share(f);
      AppToast.show('Backup ready — save it somewhere safe', icon: Icons.cloud_done_rounded);
    } catch (_) {
      AppToast.show('Could not create the backup', kind: ToastKind.error);
    }
  }

  Future<void> _import() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (picked == null) return;
      final path = picked.path;
      if (path == null) throw const FormatException('Could not read that file.');
      final preview = BackupService.parse(await File(path).readAsString());
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text('${preview.commits} committed days, ${preview.tasks} tasks, ${preview.vault} vault items and '
              '${preview.friends} friends.\n\nThis replaces what is on this phone now.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
          ],
        ),
      );
      if (ok == true) {
        ref.read(appProvider.notifier).replaceState(preview.state);
        gh.text = preview.state.githubUser;
        lc.text = preview.state.leetcodeUser;
        cf.text = preview.state.codeforcesUser;
        AppToast.show('Backup restored', icon: Icons.restore_rounded);
      }
    } on FormatException catch (e) {
      AppToast.show(e.message, kind: ToastKind.error);
    } catch (_) {
      AppToast.show('Could not import that file', kind: ToastKind.error);
    }
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
            _SyncStatus(state: s, id: 'github', username: s.githubUser),
            const SizedBox(height: 10),
            TextField(controller: lc, autocorrect: false, decoration: const InputDecoration(labelText: 'LeetCode username', prefixIcon: Icon(Icons.terminal))),
            _SyncStatus(state: s, id: 'leetcode', username: s.leetcodeUser),
            const SizedBox(height: 10),
            TextField(controller: cf, autocorrect: false, decoration: const InputDecoration(labelText: 'Codeforces handle', prefixIcon: Icon(Icons.bar_chart_rounded))),
            _SyncStatus(state: s, id: 'codeforces', username: s.codeforcesUser),
            const SizedBox(height: 6),
            Text('Only public profile data is read. Commit never asks for a password.',
                style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: syncing ? null : _saveAccounts, child: Text(syncing ? 'Syncing…' : 'Save & sync')),
            ),
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
                  AppToast.show('Reminder on · ${s.reminderHour.toString().padLeft(2, '0')}:00 each evening', icon: Icons.notifications_active_rounded);
                } else {
                  await NotificationService.instance.cancelAll();
                  AppToast.show('Reminders off', kind: ToastKind.info, icon: Icons.notifications_off_rounded);
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
                  AppToast.show('Reminder set for ${t.hour.toString().padLeft(2, '0')}:00', icon: Icons.alarm_on_rounded);
                }
              },
            ),
            ListTile(
              title: const Text('Plan a rest day for tomorrow'),
              subtitle: const Text('Rest days keep your streak. Recovery is part of the work.'),
              trailing: s.restDays.contains(addDays(today, 1)) ? Icon(Icons.check_circle, color: cc.success) : null,
              onTap: () {
                final already = s.restDays.contains(addDays(today, 1));
                n.scheduleRestDay(addDays(today, 1));
                AppToast.show(
                  already ? 'Tomorrow is already a rest day' : 'Rest day planned for tomorrow — your streak is safe',
                  kind: already ? ToastKind.info : ToastKind.success,
                  icon: Icons.self_improvement_rounded,
                );
              },
            ),
            SwitchListTile(
              title: const Text('Lock vault with biometrics'),
              value: prefs.getBool(vaultLockKey) ?? false,
              onChanged: (v) async {
                await prefs.setBool(vaultLockKey, v);
                setState(() {});
                AppToast.show(v ? 'Vault lock on' : 'Vault lock off', icon: v ? Icons.lock_rounded : Icons.lock_open_rounded);
              },
            ),
          ]),
        ),
        const SectionTitle('Data'),
        CCard(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Export backup'),
              subtitle: const Text('Save everything to a file — share it to Drive or email.'),
              onTap: () => _export(),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Import backup'),
              subtitle: const Text('Restore from a Commit backup file.'),
              onTap: () => _import(),
            ),
            ListTile(
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
              if (ok == true) {
                n.resetAll();
                AppToast.show('All data cleared', kind: ToastKind.info);
              }
            },
          ),
          ]),
        ),
      ]),
    );
  }
}

/// Persistent per-platform status under each username field.
class _SyncStatus extends StatelessWidget {
  final AppState state;
  final String id, username;
  const _SyncStatus({required this.state, required this.id, required this.username});

  @override
  Widget build(BuildContext context) {
    if (username.isEmpty) return const SizedBox.shrink();
    final err = state.syncErrors[id];
    final snap = state.snapshots[id];
    final cc = context.cc;
    final String text;
    final Color color;
    final IconData icon;
    if (err != null) {
      text = '$err — showing ${snap == null ? 'no' : 'cached'} data';
      color = cc.warning;
      icon = Icons.error_outline_rounded;
    } else if (snap != null) {
      final t = TimeOfDay.fromDateTime(snap.fetchedAt).format(context);
      text = 'Synced at $t';
      color = cc.success;
      icon = Icons.check_circle_outline_rounded;
    } else {
      text = 'Not synced yet';
      color = cc.textSecondary;
      icon = Icons.sync_rounded;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: color))),
      ]),
    );
  }
}
