/// sync_status_bar.dart — v2.7
/// A compact status bar that shows online/offline state, pending queue
/// count, last sync time, and a manual sync button.
/// Also shows a conflict banner when the server rejects batch items.
///
/// Embed at the top of any screen that benefits from sync awareness:
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('...')),
///       body: Column(children: [
///         const SyncStatusBar(),
///         Expanded(child: ...),
///       ]),
///     );
///   }
library sync_status_bar;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/sync_service.dart';
import 'sync_conflict_dialog.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: SyncService.instance,
      child: const _SyncBar(),
    );
  }
}

class _SyncBar extends StatelessWidget {
  const _SyncBar();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final online  = sync.isOnline;
    final pending = sync.pendingCount + sync.pendingShiftUpdateCount;
    final syncing = sync.isSyncing;
    final lastSync = sync.lastSyncAt;
    final conflicts = sync.rejectedItems;

    final bgColor = online
        ? (pending > 0 ? Colors.orange.shade50 : Colors.green.shade50)
        : Colors.red.shade50;

    final fgColor = online
        ? (pending > 0 ? Colors.orange.shade800 : Colors.green.shade800)
        : Colors.red.shade800;

    String statusText;
    if (!online) {
      statusText = l10n.syncOffline;
    } else if (syncing) {
      statusText = l10n.syncSyncing;
    } else if (pending > 0) {
      statusText = l10n.syncPendingCount(pending);
    } else {
      statusText = l10n.syncUpToDate;
    }

    String? subText;
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inMinutes < 1) {
        subText = l10n.syncJustNow;
      } else if (diff.inHours < 1) {
        subText = l10n.syncMinutesAgo(diff.inMinutes);
      } else {
        subText = l10n.syncHoursAgo(diff.inHours);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main status bar ───────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // Status icon
              Icon(
                online
                    ? (pending > 0 ? Icons.cloud_upload : Icons.cloud_done)
                    : Icons.cloud_off,
                size: 16,
                color: fgColor,
              ),
              const SizedBox(width: 6),

              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subText != null)
                      Text(
                        subText,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: fgColor.withOpacity(0.8)),
                      ),
                  ],
                ),
              ),

              // Pending badge
              if (pending > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),

              // Manual sync button
              if (online)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: syncing
                      ? Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: fgColor),
                        )
                      : IconButton(
                          icon: Icon(Icons.refresh, size: 18, color: fgColor),
                          onPressed: () => SyncService.instance.syncNow(),
                          tooltip: l10n.syncNow,
                          padding: EdgeInsets.zero,
                        ),
                ),
            ],
          ),
        ),

        // ── Conflict banner (shown only when server rejected items) ───────
        if (conflicts.isNotEmpty)
          Material(
            color: Colors.deepOrange.shade50,
            child: InkWell(
              onTap: () => SyncConflictDialog.show(context, rejected: conflicts),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.sync_problem,
                        size: 16, color: Colors.deepOrange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.syncConflictTitle +
                            ' (${conflicts.length}) — ${l10n.syncConflictRetry}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.deepOrange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: Colors.deepOrange.shade700),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
