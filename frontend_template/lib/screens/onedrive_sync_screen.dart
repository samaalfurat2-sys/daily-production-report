import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class OneDriveSyncScreen extends StatefulWidget {
  const OneDriveSyncScreen({super.key});
  @override
  State<OneDriveSyncScreen> createState() => _OneDriveSyncScreenState();
}

class _OneDriveSyncScreenState extends State<OneDriveSyncScreen> {
  bool _loading = false;
  bool _syncing = false;
  List<dynamic> _files = [];
  String? _error;
  String? _msUser;

  // Device-code auth flow state
  String _userCode = '';          // human-readable code shown to user
  String _deviceCode = '';        // actual device_code sent to poll API  ← FIX
  String _verificationUri = '';
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app = context.read<AppState>();
      if (app.isConnectedToOneDrive) {
        final me = await app.graph.getMe();
        final files = await app.graph.listFiles('ProductionReports/db');
        if (mounted) setState(() {
          _msUser = me['userPrincipalName'] ?? me['displayName'] ?? me['mail'] ?? '';
          _files = files;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startAuth() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app = context.read<AppState>();
      final info = await app.connectOneDrive();
      if (mounted) setState(() {
        _userCode = info['user_code'] ?? '';
        _deviceCode = info['device_code'] ?? '';          // ← store device_code separately
        _verificationUri = info['verification_uri'] ?? 'https://microsoft.com/devicelogin';
        _authInProgress = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pollAuth() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app = context.read<AppState>();
      final ok = await app.pollOneDriveConnection(_deviceCode);  // ← pass device_code not user_code
      if (mounted) {
        if (ok) {
          setState(() { _authInProgress = false; });
          await _checkStatus();
        } else {
          setState(() { _error = 'Not confirmed yet. Try again after entering the code.'; _loading = false; });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _syncAll() async {
    setState(() { _syncing = true; _error = null; });
    try {
      final app = context.read<AppState>();
      final shifts = await app.db.getShifts(limit: 10000);
      final ts = DateTime.now().millisecondsSinceEpoch;
      await app.graph.writeJsonFile('ProductionReports/db/shifts_$ts.json', shifts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Synced successfully')));
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnect() async {
    final app = context.read<AppState>();
    await app.disconnectOneDrive();
    if (mounted) setState(() { _msUser = null; _files = []; _authInProgress = false; _deviceCode = ''; _userCode = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    final connected = app.isConnectedToOneDrive;
    final ar = app.locale?.languageCode == 'ar';

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.oneDriveSync),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _checkStatus)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status card
                    Card(
                      child: ListTile(
                        leading: Icon(
                          connected ? Icons.cloud_done : Icons.cloud_off,
                          color: connected ? Colors.green : Colors.red,
                          size: 36,
                        ),
                        title: Text(connected ? (ar ? 'متصل' : 'Connected') : (ar ? 'غير متصل' : 'Not Connected')),
                        subtitle: _msUser != null && _msUser!.isNotEmpty ? Text(_msUser!) : null,
                        trailing: connected
                            ? IconButton(icon: const Icon(Icons.link_off, color: Colors.red), onPressed: _disconnect)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Not connected: show connect button or device-code flow
                    if (!connected) ...[
                      if (!_authInProgress) ...[
                        // Info text for personal account
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                ar
                                  ? 'سيتم ربط OneDrive الشخصي (Outlook / Hotmail / Live). استخدم حساب Microsoft الشخصي فقط.'
                                  : 'Connects to your personal OneDrive (Outlook / Hotmail / Live). Use your personal Microsoft account only.',
                                style: const TextStyle(color: Colors.blue, fontSize: 13),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
                            icon: const Icon(Icons.cloud_sync),
                            label: Text(ar ? 'ربط OneDrive الشخصي' : 'Connect Personal OneDrive'),
                            onPressed: _startAuth,
                          ),
                        ),
                      ] else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ar ? 'الخطوة 1: افتح هذا الرابط في المتصفح:' : 'Step 1: Open this URL in your browser:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SelectableText(_verificationUri, style: const TextStyle(color: Color(0xFF0078D4))),
                                const SizedBox(height: 12),
                                Text(ar ? 'الخطوة 2: أدخل هذا الكود وسجّل دخولك بحساب Microsoft الشخصي:' : 'Step 2: Enter this code and sign in with your personal Microsoft account:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: SelectableText(_userCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6))),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ar ? '⚠️ أدخل الكود في الموقع أعلاه باستخدام حساب Outlook/Hotmail/Live الشخصي فقط.' : '⚠️ Enter the code on the website above using your personal Outlook/Hotmail/Live account only.',
                                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.check),
                                        label: Text(ar ? '✅ تم تسجيل الدخول' : '✅ I\'ve signed in'),
                                        onPressed: _pollAuth,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => setState(() { _authInProgress = false; _deviceCode = ''; _userCode = ''; }),
                                        child: Text(ar ? 'إلغاء' : 'Cancel'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Connected: show sync buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
                          icon: _syncing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync),
                          label: Text(ar ? 'مزامنة الكل' : 'Sync All'),
                          onPressed: _syncing ? null : _syncAll,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Files list
                      Text(ar ? 'الملفات في OneDrive الشخصي' : 'Files in Personal OneDrive',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_files.isEmpty)
                        Text(ar ? 'لا توجد ملفات بعد' : 'No files yet', style: const TextStyle(color: Colors.grey))
                      else
                        ..._files.map((f) {
                          final name = (f as Map<String, dynamic>)['name'] ?? '';
                          final size = f['size'] ?? 0;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(name.toString()),
                            subtitle: Text('$size bytes'),
                          );
                        }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
