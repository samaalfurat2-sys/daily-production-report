import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'shift_detail_screen.dart';
import '../services/local_db.dart';

/// A list of shifts shown either as a standalone screen (push navigation)
/// or embedded as a tab child (no inner Scaffold in that case).
///
/// Supports optional date-range filtering via a calendar picker.
class ShiftListScreen extends StatefulWidget {
  /// When [embedded] is true the widget renders as a plain list (no AppBar /
  /// outer Scaffold) so that it can be safely placed inside a TabBarView.
  final bool embedded;

  const ShiftListScreen({super.key, this.embedded = false});

  @override
  State<ShiftListScreen> createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends State<ShiftListScreen> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _error;
  bool _isOfflineFallback = false;

  // ── Date filter ──────────────────────────────────────────────────────────
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      _isOfflineFallback = false;
      _items = await appState.api.listShifts(
        limit: 200,
        dateFrom: _dateFrom != null ? _fmtDate(_dateFrom!) : null,
        dateTo: _dateTo != null ? _fmtDate(_dateTo!) : null,
      );
    } catch (e) {
      // Offline fallback — serve cached shifts from SQLite
      try {
        final cached = await LocalDb.instance.getCachedShifts();
        if (cached.isNotEmpty) {
          _items = cached;
          _isOfflineFallback = true;
        } else {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
    );
    if (range != null) {
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end;
      });
      await _load();
    }
  }

  void _clearFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _buildFilterChip(AppLocalizations t) {
    if (_dateFrom == null && _dateTo == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(children: [
        Chip(
          avatar: const Icon(Icons.date_range, size: 16),
          label: Text(
            '${_fmtDate(_dateFrom!)} – ${_fmtDate(_dateTo!)}',
            style: const TextStyle(fontSize: 12),
          ),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: _clearFilter,
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        ),
      ]),
    );
  }

  Widget _buildList(AppLocalizations t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_isOfflineFallback)
          Material(
            color: Colors.orange.shade100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(t.offlineCachedData,
                    style: const TextStyle(fontSize: 12, color: Colors.orange))),
              ]),
            ),
          ),
        Expanded(child: _buildListContent(t)),
      ],
    );
  }

  Widget _buildListContent(AppLocalizations t) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(t.refresh),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Column(
        children: [
          _buildFilterChip(t),
          Expanded(child: Center(child: Text(t.noData))),
        ],
      );
    }

    return Column(
      children: [
        _buildFilterChip(t),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final it = _items[i] as Map<String, dynamic>;
                final status = it['status'] as String? ?? '';
                return ListTile(
                  title: Text(
                    '${it['report_date']} • ${t.shiftCode}: ${it['shift_code']}',
                  ),
                  subtitle: Text('${t.status}: $status'),
                  leading: _statusIcon(status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ShiftDetailScreen(shiftId: it['id'].toString()),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'Draft':
        return const CircleAvatar(
            backgroundColor: Colors.grey, radius: 12,
            child: Icon(Icons.edit_outlined, size: 14, color: Colors.white));
      case 'Submitted':
        return CircleAvatar(
            backgroundColor: Colors.orange[700], radius: 12,
            child: const Icon(Icons.upload_outlined, size: 14, color: Colors.white));
      case 'Approved':
        return CircleAvatar(
            backgroundColor: Colors.blue[700], radius: 12,
            child: const Icon(Icons.verified_outlined, size: 14, color: Colors.white));
      case 'Locked':
        return CircleAvatar(
            backgroundColor: Colors.green[700], radius: 12,
            child: const Icon(Icons.lock_outlined, size: 14, color: Colors.white));
      default:
        return const CircleAvatar(
            backgroundColor: Colors.grey, radius: 12,
            child: Icon(Icons.help_outline, size: 14, color: Colors.white));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasFilter = _dateFrom != null || _dateTo != null;

    // ── Embedded mode: no Scaffold/AppBar ─────────────────────────────────
    if (widget.embedded) {
      return Column(
        children: [
          // Filter action bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasFilter)
                  TextButton.icon(
                    onPressed: _clearFilter,
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: Text(t.clearFilter,
                        style: const TextStyle(fontSize: 12)),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.date_range,
                    color: hasFilter
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: t.filterByDate,
                  onPressed: _pickDateRange,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: t.refresh,
                  onPressed: _load,
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(t)),
        ],
      );
    }

    // ── Standalone mode: full Scaffold with AppBar ────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: Text(t.shifts),
        actions: [
          if (hasFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: t.clearFilter,
              onPressed: _clearFilter,
            ),
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: hasFilter
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: t.filterByDate,
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildList(t),
    );
  }
}
