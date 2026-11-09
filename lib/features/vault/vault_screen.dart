import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/icons.dart';

const vaultLockKey = 'vault_lock';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});
  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  WalletKind? kind; // null = all
  String query = '';
  bool unlocked = false;
  bool get locked => ref.read(prefsProvider).getBool(vaultLockKey) ?? false;

  Future<void> _unlock() async {
    try {
      final ok = await LocalAuthentication().authenticate(localizedReason: 'Unlock your vault');
      if (ok && mounted) setState(() => unlocked = true);
    } catch (_) {
      // No biometrics available: fail open rather than lock the user out of their own data.
      if (mounted) setState(() => unlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (locked && !unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vault')),
        body: Center(
          child: EmptyState(icon: AppIcons.lockKey, title: 'Vault is locked', subtitle: 'Authenticate to see your ideas and hackathons.', cta: 'Unlock', onCta: _unlock),
        ),
      );
    }
    final s = ref.watch(appProvider);
    final q = query.toLowerCase();
    final items = s.wallet.where((w) {
      if (kind != null && w.kind != kind) return false;
      if (q.isEmpty) return true;
      return w.title.toLowerCase().contains(q) ||
          w.body.toLowerCase().contains(q) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search ideas, tags, hackathons'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: const Text('All'), selected: kind == null, onSelected: (_) => setState(() => kind = null)),
            ),
            for (final k in WalletKind.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setState(() => kind = k)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyState(
            icon: AppIcons.lightbulb,
            title: s.wallet.isEmpty ? 'Your vault is empty' : 'No matches',
            subtitle: 'Ideas, hackathons, projects and links live here. Hold the + button for a 5-second idea.',
            cta: 'Add to vault',
            onCta: () => showAddWallet(context, kind ?? WalletKind.idea),
          )
        else
          for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _WalletCard(item: w)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showAddWallet(context, kind ?? WalletKind.idea),
          icon: const Icon(Icons.add),
          label: const Text('New entry'),
        ),
      ]),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  final WalletItem item;
  const _WalletCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final color = cc.kindColor(item.kind.name);
    final n = ref.read(appProvider.notifier);
    final today = ref.watch(todayProvider);
    String? countdown;
    if (item.kind == WalletKind.hackathon && item.extra['start'] != null) {
      try {
        final d = daysBetween(today, item.extra['start']!);
        countdown = d > 0 ? 'in $d days' : d == 0 ? 'today' : 'started';
      } catch (_) {}
    }
    return Dismissible(
      key: ValueKey('wallet-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: context.scheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: Icon(AppIcons.trash, color: context.scheme.error),
      ),
      confirmDismiss: (_) => confirmDestructive(
        context,
        title: 'Delete ${item.kind.name}?',
        message: '“${item.title}” will be removed from your vault. You can undo right after.',
      ),
      onDismissed: (_) {
        n.deleteWallet(item.id);
        AppToast.show('${item.kind.name[0].toUpperCase()}${item.kind.name.substring(1)} deleted',
            kind: ToastKind.info, icon: Icons.delete_outline_rounded, actionLabel: 'Undo', onAction: () => n.restoreWallet(item));
      },
      child: CCard(
        onTap: () => showAddWallet(context, item.kind, existing: item),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Pill(item.kind == WalletKind.snippet && (item.extra['lang'] ?? '').isNotEmpty ? 'snippet · ${item.extra['lang']}' : item.kind.name, color: color),
            const SizedBox(width: 6),
            if (item.kind == WalletKind.idea) Pill(item.status, color: cc.textSecondary),
            if (countdown != null) Pill(countdown, color: cc.warning, icon: Icons.timer_outlined),
            const Spacer(),
            IconButton(
              tooltip: item.pinned ? 'Unpin' : 'Pin',
              visualDensity: VisualDensity.compact,
              icon: Icon(item.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
              onPressed: () {
                n.togglePin(item.id);
                AppToast.show(item.pinned ? 'Unpinned' : 'Pinned to top', kind: ToastKind.info, icon: Icons.push_pin_rounded);
              },
            ),
          ]),
          const SizedBox(height: 6),
          Text(item.title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (item.body.isNotEmpty && item.kind == WalletKind.snippet)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cc.surfaceRaised, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(item.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono(context, size: 12, weight: FontWeight.w500)),
                ),
                IconButton(
                  tooltip: 'Copy snippet',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.body));
                    AppToast.show('Snippet copied', icon: Icons.copy_rounded);
                  },
                ),
              ]),
            )
          else if (item.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)),
            ),
          if (item.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, children: [for (final t in item.tags) Pill('#$t')]),
            ),
        ]),
      ),
    );
  }
}

Future<void> showAddWallet(BuildContext context, WalletKind kind, {WalletItem? existing}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WalletForm(kind: kind, existing: existing),
    );

class _WalletForm extends ConsumerStatefulWidget {
  final WalletKind kind;
  final WalletItem? existing;
  const _WalletForm({required this.kind, this.existing});
  @override
  ConsumerState<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends ConsumerState<_WalletForm> {
  late WalletKind kind = widget.kind;
  late final title = TextEditingController(text: widget.existing?.title);
  late final body = TextEditingController(text: widget.existing?.body);
  late final tags = TextEditingController(text: widget.existing?.tags.join(', '));
  late final link = TextEditingController(text: widget.existing?.extra['link']);
  late final start = TextEditingController(text: widget.existing?.extra['start']);
  late final team = TextEditingController(text: widget.existing?.extra['team']);
  late final lang = TextEditingController(text: widget.existing?.extra['lang']);
  late String status = widget.existing?.status ?? 'raw';

  void save() {
    if (title.text.trim().isEmpty) return;
    final n = ref.read(appProvider.notifier);
    if (widget.existing != null) n.deleteWallet(widget.existing!.id);
    n.addWallet(WalletItem(
      id: '',
      kind: kind,
      title: title.text.trim(),
      body: body.text.trim(),
      tags: tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      status: status,
      pinned: widget.existing?.pinned ?? false,
      extra: {
        if (link.text.trim().isNotEmpty) 'link': link.text.trim(),
        if (start.text.trim().isNotEmpty) 'start': start.text.trim(),
        if (team.text.trim().isNotEmpty) 'team': team.text.trim(),
        if (lang.text.trim().isNotEmpty) 'lang': lang.text.trim(),
      },
    ));
    Navigator.pop(context);
    AppToast.show(widget.existing != null ? 'Changes saved' : 'Saved to vault', icon: Icons.lock_rounded);
  }

  Future<void> delete() async {
    final item = widget.existing!;
    final ok = await confirmDestructive(context,
        title: 'Delete ${item.kind.name}?', message: '“${item.title}” will be removed from your vault. You can undo right after.');
    if (!ok || !mounted) return;
    final n = ref.read(appProvider.notifier);
    n.deleteWallet(item.id);
    Navigator.pop(context);
    AppToast.show('${item.kind.name[0].toUpperCase()}${item.kind.name.substring(1)} deleted',
        kind: ToastKind.info, icon: Icons.delete_outline_rounded, actionLabel: 'Undo', onAction: () => n.restoreWallet(item));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, children: [
              for (final k in WalletKind.values)
                ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setState(() => kind = k)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: title, autofocus: widget.existing == null, decoration: InputDecoration(hintText: switch (kind) {
              WalletKind.idea => 'Idea title',
              WalletKind.hackathon => 'Hackathon name',
              WalletKind.project => 'Project name',
              WalletKind.resource => 'Resource title',
              WalletKind.snippet => 'Snippet title',
            })),
            const SizedBox(height: 10),
            if (kind == WalletKind.snippet) ...[
              TextField(controller: lang, decoration: const InputDecoration(hintText: 'Language (dart, python, sql…)')),
              const SizedBox(height: 10),
              TextField(
                controller: body,
                maxLines: 8,
                minLines: 4,
                style: AppTheme.mono(context, size: 13, weight: FontWeight.w500),
                decoration: const InputDecoration(hintText: 'Paste your code'),
              ),
            ] else
              TextField(controller: body, maxLines: 3, decoration: InputDecoration(hintText: kind == WalletKind.hackathon ? 'Theme / problem statement' : 'Description')),
            if (kind == WalletKind.idea) ...[
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'raw', label: Text('Raw')),
                  ButtonSegment(value: 'in progress', label: Text('In progress')),
                  ButtonSegment(value: 'shelved', label: Text('Shelved')),
                ],
                selected: {status},
                onSelectionChanged: (v) => setState(() => status = v.first),
              ),
            ],
            if (kind == WalletKind.hackathon) ...[
              const SizedBox(height: 10),
              TextField(controller: start, decoration: const InputDecoration(hintText: 'Start date (YYYY-MM-DD)')),
              const SizedBox(height: 10),
              TextField(controller: team, decoration: const InputDecoration(hintText: 'Team members')),
            ],
            if (kind != WalletKind.idea && kind != WalletKind.snippet) ...[
              const SizedBox(height: 10),
              TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'Link (repo, submission, doc)')),
            ],
            const SizedBox(height: 10),
            TextField(controller: tags, decoration: const InputDecoration(hintText: 'Tags, comma separated')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Save'))),
            if (widget.existing != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: context.scheme.error),
                  icon: const Icon(AppIcons.trash, size: 18),
                  label: const Text('Delete'),
                  onPressed: delete,
                ),
              ),
          ]),
        ),
      );
}
