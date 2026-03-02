import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'shift_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _shiftCode = TextEditingController(text: 'A');
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _shiftCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final dateText = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text(t.dashboard)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(t.createShift, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: _date,
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: t.reportDate, border: const OutlineInputBorder()),
                        child: Text(dateText),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shiftCode,
                      decoration: InputDecoration(labelText: t.shiftCode, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () async {
                          setState(() => _loading = true);
                          try {
                            final shift = await appState.db.createShift(reportDate: dateText, shiftCode: _shiftCode.text.trim());
                            if (!mounted) return;
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftDetailScreen(shiftId: shift['id'].toString())));
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: _loading ? const CircularProgressIndicator() : Text(t.open),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
