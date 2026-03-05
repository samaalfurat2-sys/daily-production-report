import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/sync_service.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/sync_conflict_dialog.dart';

// FIX: Converted from StatelessWidget to StatefulWidget so that
// TextEditingController is properly initialised once and disposed
// when the widget leaves the tree. Previously the controller was
// re-created on every build() call, causing a memory leak.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _serverController = TextEditingController(text: appState.serverUrl);
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(title: Text(t.language)),
            SegmentedButton<Locale>(
              segments: [
                ButtonSegment(value: const Locale('ar'), label: Text(t.arabic)),
                ButtonSegment(value: const Locale('en'), label: Text(t.english)),
              ],
              selected: {appState.locale ?? const Locale('ar')},
              onSelectionChanged: (s) => appState.setLocale(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverController,
              decoration: InputDecoration(labelText: t.serverUrl, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => appState.setServerUrl(_serverController.text),
              child: Text(t.save),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => appState.logout(),
              icon: const Icon(Icons.logout),
              label: Text(t.signOut),
            ),
            const SizedBox(height: 24),
            // ── Sync info ──────────────────────────────────────────────────
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: Text(t.syncNow),
              subtitle: Builder(builder: (ctx) {
                final sync = ctx.watch<SyncService>();
                final lastSync = sync.lastSyncAt;
                if (lastSync == null) return Text(t.syncOffline);
                return Text('${t.syncUpToDate} — ${lastSync.toLocal().toIso8601String().substring(0,16)}');
              }),
              trailing: Builder(builder: (ctx) {
                final sync = ctx.watch<SyncService>();
                return sync.isSyncing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => SyncService.instance.syncNow(),
                      );
              }),
            ),
            const SyncStatusBar(),
            // ── Conflict count tile ────────────────────────────────────────
            Builder(builder: (ctx) {
              final sync = ctx.watch<SyncService>();
              final count = sync.rejectedItems.length;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Colors.deepOrange),
                title: Text(
                  '${t.syncConflictTitle} ($count)',
                  style: const TextStyle(
                      color: Colors.deepOrange, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(t.syncConflictSubtitle(sync.rejectedItems.length.toString())),
                trailing: TextButton(
                  onPressed: () => SyncConflictDialog.show(ctx, rejected: sync.rejectedItems),
                  child: Text(t.open),
                ),
              );
            }),
            // ── Pending shift unit updates tile ───────────────────────────
            Builder(builder: (ctx) {
              final sync = SyncService.instance;
              final count = sync.pendingShiftUpdateCount;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.amber),
                title: Text(
                  '${t.syncShiftPending(count)}',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Will sync automatically when online'),
              );
            }),
          ],
        ),
      ),
    );
  }
}
