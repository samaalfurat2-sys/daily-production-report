import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'shift_detail_screen.dart';
import '../services/local_db.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _error;
  bool _isOfflineFallback = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final appState = context.read<AppState>();
      _isOfflineFallback = false;
      _items = await appState.api.listShifts(status: 'Submitted', limit: 200);
    } catch (e) {
      // Offline fallback — show cached submitted shifts
      try {
        final cached = await LocalDb.instance.getCachedShifts();
        final submitted = cached
            .where((s) => (s['status'] ?? '').toString() == 'Submitted')
            .toList();
        if (submitted.isNotEmpty) {
          _items = submitted;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(t.approvals),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null
          ? Center(child: Text(_error!))
          : Column(
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
                if (_items.isEmpty)
                  Expanded(child: Center(child: Text(t.noPendingApprovals)))
                else
                  Expanded(child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _items[i] as Map<String, dynamic>;
                    final id = it['id'].toString();
                    return ListTile(
                      title: Text('${it['report_date']} • ${t.shiftCode}: ${it['shift_code']}'),
                      subtitle: Text('${t.status}: ${it['status']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: t.approve,
                            icon: const Icon(Icons.check_circle_outline),
                            // FIX: wrap in try/catch so a network or 4xx error
                            // is surfaced as a SnackBar instead of an unhandled
                            // exception that silently drops the failure.
                            onPressed: () async {
                              try {
                                await appState.api.approveShift(id);
                                await _load();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            tooltip: t.open,
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftDetailScreen(shiftId: id))),
                          ),
                        ],
                      ),
                    );
                  },
                )),
              ],
            ),
    );
  }
}
