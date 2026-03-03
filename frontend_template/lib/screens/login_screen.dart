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
  bool _showOneDriveFlow = false;
  String _uc='', _dc='', _uri='';

  @override void dispose() { _uCtrl.dispose(); _pCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), actions: [
        PopupMenuButton<String>(
          onSelected: (v) => app.setLocale(Locale(v)),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'ar', child: Text(t.arabic)),
            PopupMenuItem(value: 'en', child: Text(t.english)),
          ]),
      ]),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Card(child: Padding(padding: const EdgeInsets.all(20),
            child: _showOneDriveFlow ? _oneDriveFlowWidget(app, t) : _loginForm(app, t),
          ))))),
    );
  }

  Widget _loginForm(AppState app, AppLocalizations t) {
    final ar = app.locale?.languageCode == 'ar';
    return Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
      // App icon / title
      const Icon(Icons.factory_outlined, size: 56, color: Color(0xFF0078D4)),
      const SizedBox(height: 8),
      Text(t.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),

      // OneDrive status banner (informational, NOT blocking)
      _oneDriveBanner(app, ar),
      const SizedBox(height: 16),

      // Username
      TextFormField(
        controller: _uCtrl,
        decoration: InputDecoration(labelText: t.username, prefixIcon: const Icon(Icons.person_outline)),
        textInputAction: TextInputAction.next,
        validator: (v) => (v == null || v.trim().isEmpty) ? t.username : null,
      ),
      const SizedBox(height: 10),

      // Password
      TextFormField(
        controller: _pCtrl,
        decoration: InputDecoration(labelText: t.password, prefixIcon: const Icon(Icons.lock_outline)),
        obscureText: true,
        textInputAction: TextInputAction.done,
        validator: (v) => (v == null || v.isEmpty) ? t.password : null,
        onFieldSubmitted: (_) => _login(app, t),
      ),
      const SizedBox(height: 16),

      // Error message
      if (_err != null) ...[
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_err!, style: TextStyle(color: Colors.red.shade700))),
          ])),
        const SizedBox(height: 12),
      ],

      // Login button
      SizedBox(width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : () => _login(app, t),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t.signIn, style: const TextStyle(fontSize: 16)),
        )),

      // Storage mode indicator
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          app.isConnectedToOneDrive ? Icons.cloud_done : Icons.phone_android,
          size: 14,
          color: app.isConnectedToOneDrive ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          app.isConnectedToOneDrive
              ? (ar ? 'بيانات: OneDrive' : 'Data: OneDrive')
              : (ar ? 'بيانات: محلي على الجهاز' : 'Data: Local device'),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]),
    ]));
  }

  Widget _oneDriveBanner(AppState app, bool ar) {
    if (app.isConnectedToOneDrive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.cloud_done, color: Colors.green.shade700, size: 18),
          const SizedBox(width: 8),
          Text(ar ? '☁️ OneDrive متصل' : '☁️ OneDrive connected',
            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w500)),
        ]));
    }
    // Not connected – show optional connect button
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(
            ar ? 'يعمل التطبيق بدون OneDrive (تخزين محلي)' : 'App works without OneDrive (local storage)',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 12))),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.cloud_sync, size: 16),
            label: Text(ar ? 'ربط OneDrive (اختياري)' : 'Connect OneDrive (optional)',
              style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0078D4),
              side: const BorderSide(color: Color(0xFF0078D4)),
              padding: const EdgeInsets.symmetric(vertical: 8)),
            onPressed: _startOneDriveFlow,
          )),
      ]));
  }

  Widget _oneDriveFlowWidget(AppState app, AppLocalizations t) {
    final ar = app.locale?.languageCode == 'ar';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(ar ? 'ربط Microsoft OneDrive' : 'Connect Microsoft OneDrive',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Text(ar ? 'الخطوة 1: افتح هذا الرابط:' : 'Step 1: Open this URL:',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      SelectableText(_uri, style: const TextStyle(color: Color(0xFF0078D4))),
      const SizedBox(height: 12),
      Text(ar ? 'الخطوة 2: أدخل هذا الكود:' : 'Step 2: Enter this code:',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF0078D4), width: 2),
          borderRadius: BorderRadius.circular(8)),
        child: Text(_uc, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF0078D4)))),
      const SizedBox(height: 12),
      Text(ar ? 'الخطوة 3: بعد تسجيل الدخول اضغط:' : 'Step 3: After sign-in, tap:',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_busy) const Center(child: CircularProgressIndicator())
      else ...[
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => _completeOneDriveFlow(app),
            child: Text(ar ? '✅ أكملت تسجيل الدخول' : '✅ I completed sign-in'))),
        TextButton(
          onPressed: () => setState(() => _showOneDriveFlow = false),
          child: Text(ar ? 'إلغاء – استمر بدون OneDrive' : 'Cancel – continue without OneDrive')),
      ],
      if (_err != null) ...[const SizedBox(height: 8), Text(_err!, style: const TextStyle(color: Colors.red))],
    ]);
  }

  Future<void> _startOneDriveFlow() async {
    setState(() { _busy = true; _err = null; });
    try {
      final app = Provider.of<AppState>(context, listen: false);
      final r = await app.connectOneDrive();
      setState(() {
        _uc = r['user_code'] as String;
        _dc = r['device_code'] as String;
        _uri = r['verification_uri'] as String;
        _showOneDriveFlow = true;
      });
    } catch (e) { setState(() => _err = e.toString()); }
    finally { setState(() => _busy = false); }
  }

  Future<void> _completeOneDriveFlow(AppState app) async {
    setState(() { _busy = true; _err = null; });
    try {
      final ok = await app.pollOneDriveConnection(_dc);
      if (ok) {
        setState(() => _showOneDriveFlow = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(app.locale?.languageCode=='ar' ? '✅ تم ربط OneDrive!' : '✅ OneDrive connected!'),
          backgroundColor: Colors.green.shade700));
      } else {
        setState(() => _err = app.locale?.languageCode=='ar' ? 'لم يكتمل بعد، حاول مجدداً' : 'Not complete yet, try again');
      }
    } catch (e) { setState(() => _err = e.toString()); }
    finally { setState(() => _busy = false); }
  }

  Future<void> _login(AppState app, AppLocalizations t) async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      await app.login(_uCtrl.text.trim(), _pCtrl.text);
    } catch (e) {
      setState(() => _err = t.invalidCredentials);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
