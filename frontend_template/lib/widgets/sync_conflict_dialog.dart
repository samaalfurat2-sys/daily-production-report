/// sync_conflict_dialog.dart — v2.7
///
/// Shows a bottom sheet listing batch-sync items that the server rejected,
/// letting the user retry individual items or discard them.
///
/// Usage — call from anywhere after `SyncService.flushQueue()` returns:
///
///   final rejected = batchResults
///       .where((r) => r['status'] == 'error')
///       .toList();
///
///   if (rejected.isNotEmpty && context.mounted) {
///     SyncConflictDialog.show(context, rejected: rejected);
///   }
library sync_conflict_dialog;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/sync_service.dart';

class SyncConflictDialog extends StatefulWidget {
  const SyncConflictDialog({super.key, required this.rejected});

  /// List of batch-result maps whose `status == "error"`.
  /// Each map should have at minimum:
  ///   { "client_id": "...", "error": "...", "payload": {...} }
  final List<Map<String, dynamic>> rejected;

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> rejected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SyncConflictDialog(rejected: rejected),
    );
  }

  @override
  State<SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<SyncConflictDialog> {
  /// Track per-item loading state while retrying.
  final Map<String, bool> _retrying = {};
  /// Track items that have been discarded in this session.
  final Set<String> _discarded = {};

  Future<void> _retry(Map<String, dynamic> item) async {
    final clientId = item['client_id'] as String? ?? '';
    setState(() => _retrying[clientId] = true);
    try {
      final payload = Map<String, dynamic>.from(
          item['payload'] as Map<String, dynamic>? ?? item);
      await SyncService.instance.enqueueTransaction(payload);
      // Attempt immediate flush
      await SyncService.instance.syncNow();
      if (mounted) setState(() => _discarded.add(clientId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retry failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying.remove(clientId));
    }
  }

  Future<void> _discard(String clientId) async {
    // Nothing to do on server — just remove from local view.
    setState(() => _discarded.add(clientId));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final visible = widget.rejected
        .where((r) => !_discarded.contains(r['client_id'] as String? ?? ''))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            // ── Handle ────────────────────────────────────────────────────
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.syncConflictTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.close),
                  ),
                ],
              ),
            ),

            if (visible.isEmpty) ...[
              const SizedBox(height: 32),
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(t.syncConflictResolved,
                  style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 32),
            ] else ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  t.syncConflictSubtitle(visible.length),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              const Divider(),

              // ── Item list ─────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = visible[i];
                    final clientId =
                        item['client_id'] as String? ?? '(no id)';
                    final error =
                        item['error'] as String? ?? t.syncConflictUnknownError;
                    final payload = item['payload'] as Map<String, dynamic>?
                        ?? item;
                    final wh = payload['warehouse_code']?.toString() ?? '';
                    final code = payload['item_code']?.toString() ?? '';
                    final type = payload['txn_type']?.toString() ?? '';
                    final qty = payload['qty']?.toString() ?? '';
                    final isRetrying = _retrying[clientId] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      elevation: 1,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: const Icon(Icons.error_outline,
                              color: Colors.orange, size: 20),
                        ),
                        title: Text(
                          '$wh • $code • $type × $qty',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          error,
                          style: TextStyle(
                              fontSize: 12, color: Colors.red[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Expand to show full error + payload
                        children: [
                          // ── Full error message (monospace, selectable) ────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.red.shade200),
                              ),
                              child: SelectableText(
                                error,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.red[800],
                                ),
                              ),
                            ),
                          ),
                          // ── Payload key-value grid ────────────────────────
                          if (payload.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Table(
                                columnWidths: const {
                                  0: IntrinsicColumnWidth(),
                                  1: FlexColumnWidth(),
                                },
                                children: payload.entries.map((e) =>
                                  TableRow(children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 8, bottom: 2),
                                      child: Text('${e.key}:',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: Colors.black54,
                                        )),
                                    ),
                                    Text(
                                      e.value?.toString() ?? 'null',
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]),
                                ).toList(),
                              ),
                            ),
                          // ── Action row ────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: isRetrying
                                ? const Center(
                                    child: SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _retry(item),
                                        icon: const Icon(Icons.refresh,
                                            size: 16),
                                        label: Text(t.syncConflictRetry),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _discard(clientId),
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red),
                                        label: Text(
                                          t.syncConflictDiscard,
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
