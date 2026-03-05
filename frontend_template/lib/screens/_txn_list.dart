/// Shared transaction list widget with status chips and date-range filter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/local_db.dart';

class TxnList extends StatefulWidget {
  const TxnList({
    super.key,
    required this.api,
    this.warehouseCode,
    this.filterStatus,
    this.showActions = false,
    this.onAcknowledge,
    this.onPost,
    this.initialDateFrom,
    this.initialDateTo,
  });

  final ApiClient api;
  final String? warehouseCode;
  final String? filterStatus;
  final bool showActions;
  final Future<void> Function(String txnId)? onAcknowledge;
  final Future<void> Function(String txnId)? onPost;
  /// Optional pre-set date range (caller can pass parent-level dates).
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  @override
  State<TxnList> createState() => _TxnListState();
}

class _TxnListState extends State<TxnList> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  // Date-range filter state
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.listTransactions(
        warehouseCode: widget.warehouseCode,
        status: widget.filterStatus,
        dateFrom: _dateFrom != null
            ? '${_dateFrom!.year.toString().padLeft(4,'0')}-'
              '${_dateFrom!.month.toString().padLeft(2,'0')}-'
              '${_dateFrom!.day.toString().padLeft(2,'0')}'
            : null,
        dateTo: _dateTo != null
            ? '${_dateTo!.year.toString().padLeft(4,'0')}-'
              '${_dateTo!.month.toString().padLeft(2,'0')}-'
              '${_dateTo!.day.toString().padLeft(2,'0')}'
            : null,
      );
      if (mounted) setState(() { _rows = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      // Offline fallback — serve cached transactions from SQLite
      try {
        final cached = await LocalDb.instance.getCachedTxns();
        final filtered = widget.warehouseCode != null
            ? cached.where((t) => t['warehouse_code'] == widget.warehouseCode).toList()
            : cached;
        if (mounted) {
          setState(() {
            _rows = filtered.isNotEmpty ? filtered : [];
            _error = filtered.isEmpty ? e.toString() : null;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      helpText: t.filterByDate,
      confirmText: t.filterByDate,
      cancelText: t.clearFilter,
      saveText: t.filterByDate,
    );
    if (result != null) {
      setState(() { _dateFrom = result.start; _dateTo = result.end; });
      _load();
    }
  }

  void _clearDateFilter() {
    setState(() { _dateFrom = null; _dateTo = null; });
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'ACKNOWLEDGED': return Colors.blue;
      case 'POSTED': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    final t = AppLocalizations.of(context)!;
    switch (status) {
      case 'PENDING': return t.txnPending;
      case 'ACKNOWLEDGED': return t.txnAcknowledged;
      case 'POSTED': return t.txnPosted;
      default: return status;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-'
      '${d.month.toString().padLeft(2,'0')}-'
      '${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasFilter = _dateFrom != null && _dateTo != null;

    return Column(
      children: [
        // ── Date-range filter bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: hasFilter
                    ? Chip(
                        avatar: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          '${_fmtDate(_dateFrom!)} → ${_fmtDate(_dateTo!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: _clearDateFilter,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      )
                    : Text(t.filterByDate,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ),
              IconButton(
                icon: Icon(
                  Icons.date_range,
                  color: hasFilter
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
                ),
                tooltip: t.filterByDate,
                onPressed: () => _pickDateRange(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── List body ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(t.refresh),
                          ),
                        ],
                      ),
                    )
                  : _rows.isEmpty
                      ? Center(child: Text(t.noData))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final row = _rows[idx];
                              final status = (row['status'] as String?) ?? 'PENDING';
                              final txnId = row['id'] as String;

                              return ListTile(
                                isThreeLine: true,
                                leading: CircleAvatar(
                                  backgroundColor: _statusColor(status).withOpacity(0.15),
                                  child: Icon(
                                    _txnTypeIcon(row['txn_type'] as String? ?? ''),
                                    color: _statusColor(status),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${row['item_code']} – ${row['item_name_ar']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${row['txn_date']}  |  ${row['txn_type']}  |  '
                                  '${row['qty']} ${row['item_name_en'] ?? ''}\n'
                                  '${row['warehouse_name_ar']} '
                                  '${row['target_warehouse_code'] != null ? "→ ${row['target_warehouse_code']}" : ""}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Chip(
                                      label: Text(
                                        _statusLabel(context, status),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: _statusColor(status).withOpacity(0.15),
                                      side: BorderSide(color: _statusColor(status)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    if (widget.showActions &&
                                        status == 'PENDING' &&
                                        widget.onAcknowledge != null)
                                      TextButton(
                                        onPressed: () async {
                                          await widget.onAcknowledge!(txnId);
                                          _load();
                                        },
                                        child: Text(t.acknowledge,
                                            style: const TextStyle(fontSize: 11)),
                                      ),
                                    if (widget.showActions &&
                                        status == 'ACKNOWLEDGED' &&
                                        widget.onPost != null)
                                      TextButton(
                                        onPressed: () async {
                                          await widget.onPost!(txnId);
                                          _load();
                                        },
                                        child: Text(t.post,
                                            style: const TextStyle(fontSize: 11)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  IconData _txnTypeIcon(String type) {
    switch (type) {
      case 'RECEIVE': return Icons.download_outlined;
      case 'ISSUE': return Icons.upload_outlined;
      case 'TRANSFER_OUT': return Icons.arrow_forward_outlined;
      case 'TRANSFER_IN': return Icons.arrow_back_outlined;
      default: return Icons.sync_alt_outlined;
    }
  }
}
