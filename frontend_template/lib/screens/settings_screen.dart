import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    final rtl = app.locale?.languageCode == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(appBar: AppBar(title: Text(t.settings)), body: ListView(children: [
        ListTile(leading: const Icon(Icons.language), title: Text(t.language)),
        RadioListTile<String>(title: Text(t.english), value: 'en', groupValue: app.locale?.languageCode ?? 'en', onChanged: (v) => app.setLocale(Locale(v!))),
        RadioListTile<String>(title: Text(t.arabic), value: 'ar', groupValue: app.locale?.languageCode ?? 'en', onChanged: (v) => app.setLocale(Locale(v!))),
        const Divider(),
        ListTile(
          leading: Icon(app.isConnectedToOneDrive ? Icons.cloud_done : Icons.cloud_off, color: app.isConnectedToOneDrive ? Colors.green : Colors.grey),
          title: const Text('OneDrive'),
          subtitle: Text(app.isConnectedToOneDrive ? (rtl ? 'متصل' : 'Connected') : (rtl ? 'غير متصل' : 'Not connected')),
        ),
        if (app.isConnectedToOneDrive) ...[
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(rtl ? 'حساب Microsoft' : 'Microsoft Account'),
            subtitle: FutureBuilder<Map<String,dynamic>>(
              future: app.graph.getMe(),
              builder: (_, s) => Text(s.data?['userPrincipalName'] ?? s.data?['displayName'] ?? '...'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: Text(rtl ? 'قطع الاتصال' : 'Disconnect', style: const TextStyle(color: Colors.red)),
            onTap: () => _disc(context, app, rtl),
          ),
        ],
        const Divider(),
        ListTile(leading: const Icon(Icons.logout), title: Text(t.signOut), onTap: () => app.logout()),
      ]))),
    );
  }

  Future<void> _disc(BuildContext ctx, AppState app, bool ar) async {
    final ok = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      title: Text(ar ? 'قطع اتصال OneDrive؟' : 'Disconnect OneDrive?'),
      content: Text(ar ? 'ستحتاج إعادة الربط للوصول للبيانات.' : 'You will need to reconnect to access data.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ar ? 'قطع' : 'Disconnect', style: const TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await app.disconnectOneDrive(); await app.logout(); }
  }
}
