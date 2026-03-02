import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _fk = GlobalKey<FormState>();
  final _uCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _flow = false;
  String _uc='', _dc='', _uri='';

  @override void dispose() { _uCtrl.dispose(); _pCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), actions: [
        PopupMenuButton<String>(onSelected: (v) => app.setLocale(Locale(v)), itemBuilder: (_) => [
          PopupMenuItem(value: 'ar', child: Text(t.arabic)),
          PopupMenuItem(value: 'en', child: Text(t.english)),
        ]),
      ]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: const EdgeInsets.all(16), child: Card(child: Padding(padding: const EdgeInsets.all(20),
          child: _flow ? _flowWidget(app, t) : _formWidget(app, t),
        ))))),
    );
  }

  Widget _formWidget(AppState app, AppLocalizations t) {
    final ar = app.locale?.languageCode == 'ar';
    return Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(t.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      if (!app.isConnectedToOneDrive) ...[
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Row(children: [Icon(Icons.cloud_off, color: Colors.orange.shade700), const SizedBox(width: 8), Expanded(child: Text(ar ? 'يجب ربط OneDrive أولاً' : 'OneDrive not connected', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)))]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_sync), label: Text(ar ? 'ربط OneDrive' : 'Connect OneDrive'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
              onPressed: _startFlow,
            )),
          ])),
        const SizedBox(height: 16),
      ],
      TextFormField(controller: _uCtrl, decoration: InputDecoration(labelText: t.username), textInputAction: TextInputAction.next, enabled: app.isConnectedToOneDrive, validator: (v) => (v==null||v.trim().isEmpty) ? t.username : null),
      const SizedBox(height: 8),
      TextFormField(controller: _pCtrl, decoration: InputDecoration(labelText: t.password), obscureText: true, textInputAction: TextInputAction.done, enabled: app.isConnectedToOneDrive, validator: (v) => (v==null||v.isEmpty) ? t.password : null, onFieldSubmitted: (_) => _login(app, t)),
      const SizedBox(height: 16),
      if (_err != null) ...[Text(_err!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 8)],
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: (_busy || !app.isConnectedToOneDrive) ? null : () => _login(app, t),
        child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t.signIn),
      )),
    ]));
  }

  Widget _flowWidget(AppState app, AppLocalizations t) {
    final ar = app.locale?.languageCode == 'ar';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(ar ? 'ربط Microsoft OneDrive' : 'Connect Microsoft OneDrive', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Text(ar ? 'الخطوة 1: افتح هذا الرابط:' : 'Step 1: Open this URL:', style: const TextStyle(fontWeight: FontWeight.bold)),
      SelectableText(_uri, style: const TextStyle(color: Color(0xFF0078D4))),
      const SizedBox(height: 12),
      Text(ar ? 'الخطوة 2: أدخل هذا الكود:' : 'Step 2: Enter this code:', style: const TextStyle(fontWeight: FontWeight.bold)),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0078D4), width: 2), borderRadius: BorderRadius.circular(8)),
        child: Text(_uc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF0078D4)))),
      const SizedBox(height: 12),
      Text(ar ? 'الخطوة 3: بعد تسجيل الدخول اضغط:' : 'Step 3: After sign-in, tap:', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_busy) const Center(child: CircularProgressIndicator())
      else ...[
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => _completeFlow(app),
          child: Text(ar ? '✅ أكملت تسجيل الدخول' : '✅ I completed sign-in'),
        )),
        TextButton(onPressed: () => setState(() => _flow = false), child: Text(ar ? 'إلغاء' : 'Cancel')),
      ],
      if (_err != null) ...[const SizedBox(height: 8), Text(_err!, style: const TextStyle(color: Colors.red))],
    ]);
  }

  Future<void> _startFlow() async {
    setState(() { _busy = true; _err = null; });
    try {
      final app = Provider.of<AppState>(context, listen: false);
      final r = await app.connectOneDrive();
      setState(() { _uc = r['user_code'] as String; _dc = r['device_code'] as String; _uri = r['verification_uri'] as String; _flow = true; });
    } catch (e) { setState(() => _err = e.toString()); }
    finally { setState(() => _busy = false); }
  }

  Future<void> _completeFlow(AppState app) async {
    setState(() { _busy = true; _err = null; });
    try {
      final ok = await app.pollOneDriveConnection(_dc);
      if (ok) {
        setState(() { _flow = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.locale?.languageCode=='ar' ? '✅ تم ربط OneDrive!' : '✅ OneDrive connected!'), backgroundColor: Colors.green.shade700));
      } else { setState(() => _err = app.locale?.languageCode=='ar' ? 'لم يكتمل بعد، حاول مجدداً' : 'Not complete yet, try again'); }
    } catch (e) { setState(() => _err = e.toString()); }
    finally { setState(() => _busy = false); }
  }

  Future<void> _login(AppState app, AppLocalizations t) async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try { await app.login(_uCtrl.text.trim(), _pCtrl.text); }
    catch (_) { setState(() => _err = t.invalidCredentials); }
    finally { if (mounted) setState(() => _busy = false); }
  }
}
