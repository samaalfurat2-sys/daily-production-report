import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'shift_detail_screen.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final appState = context.read<AppState>();
      _items = await appState.db.listShifts(status: 'Submitted', limit: 200);
    } catch (e) {
      _error = e.toString();
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
              : _items.isEmpty
                  ? Center(child: Text(t.noPendingApprovals))
                  : ListView.separated(
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
                                onPressed: () async {
                                  await appState.db.approveShift(id);
                                  await _load();
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
                    ),
    );
  }
}
