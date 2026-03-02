import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import '../app_state.dart';
import '../services/api_client.dart';

/// OneDrive Sync screen — lets admins/supervisors trigger exports
/// and view files stored in OneDrive via the backend Microsoft Graph integration.
class OneDriveSyncScreen extends StatefulWidget {
  const OneDriveSyncScreen({super.key});
  @override
  State<OneDriveSyncScreen> createState() => _OneDriveSyncScreenState();
}

class _OneDriveSyncScreenState extends State<OneDriveSyncScreen> {
  bool _loading = false;
  String _status = '';
  bool _configured = false;
  List<dynamic> _files = [];
  String? _error;

  // Auth flow state
  String _userCode = '';
  String _deviceCode = '';
  String _verificationUri = '';
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  ApiClient get _api => Provider.of<AppState>(context, listen: false).api;

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    try {
      final result = await _api.get('/onedrive/status');
      setState(() {
        _configured = result['configured'] == true;
        _status = result['message'] ?? '';
        _error = null;
      });
      if (_configured) await _loadFiles();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFiles() async {
    try {
      final result = await _api.get('/onedrive/files');
      setState(() => _files = result['files'] ?? []);
    } catch (_) {}
  }

  Future<void> _startAuth() async {
    setState(() { _loading = true; _authInProgress = false; });
    try {
      final result = await _api.get('/onedrive/setup');
      setState(() {
        _userCode = result['user_code'] ?? '';
        _deviceCode = result['device_code'] ?? '';
        _verificationUri = result['verification_uri'] ?? 'https://microsoft.com/devicelogin';
        _authInProgress = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _completeAuth() async {
    setState(() => _loading = true);
    try {
      final result = await _api.post('/onedrive/setup/complete', {'device_code': _deviceCode});
      if (result['ok'] == true) {
        _showSnack('✅ OneDrive connected! Save the refresh token in your server environment.', success: true);
        setState(() { _authInProgress = false; });
        await _checkStatus();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _syncAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.post('/onedrive/sync/all', {});
      final errors = List<String>.from(result['errors'] ?? []);
      if (errors.isEmpty) {
        _showSnack('✅ Sync complete! Files uploaded to OneDrive.', success: true);
      } else {
        _showSnack('⚠️ Partial sync: ${errors.join('; ')}');
      }
      await _loadFiles();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportShifts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.post('/onedrive/export/shifts', {});
      _showSnack('📊 Shifts exported: ${result['filename']}', success: true);
      await _loadFiles();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportInventory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.post('/onedrive/export/inventory', {});
      _showSnack('📦 Inventory exported: ${result['filename']}', success: true);
      await _loadFiles();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _backupDb() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.post('/onedrive/backup/db', {});
      _showSnack('💾 DB backup: ${result['filename']} (${result['size_kb']} KB)', success: true);
      await _loadFiles();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green[700] : Colors.orange[700],
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isRtl = appState.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OneDrive Sync'),
          backgroundColor: const Color(0xFF0078D4), // Microsoft blue
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _checkStatus),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    if (_error != null) _buildErrorCard(),
                    if (_authInProgress) ...[
                      _buildAuthCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_configured) ...[
                      _buildSyncButtons(),
                      const SizedBox(height: 16),
                      _buildFilesList(),
                    ],
                    if (!_configured && !_authInProgress)
                      _buildConnectCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _configured ? Colors.green[50] : Colors.orange[50],
      child: ListTile(
        leading: Icon(
          _configured ? Icons.cloud_done : Icons.cloud_off,
          color: _configured ? Colors.green[700] : Colors.orange[700],
          size: 32,
        ),
        title: Text(
          _configured ? '✅ OneDrive Connected' : '⚠️ OneDrive Not Connected',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_status),
      ),
    );
  }

  Widget _buildConnectCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connect to OneDrive',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Connect your Microsoft OneDrive account to:\n'
              '• Auto-backup your database\n'
              '• Export shift reports as Excel files\n'
              '• Export inventory data as Excel files',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Connect OneDrive Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _startAuth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Microsoft Sign-In Required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Step 1: Open this URL in a browser:'),
            SelectableText(
              _verificationUri,
              style: const TextStyle(color: Color(0xFF0078D4), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Step 2: Enter this code:'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF0078D4), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _userCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Color(0xFF0078D4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Step 3: After signing in, tap the button below:'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _completeAuth,
                child: const Text('✅ I completed sign-in'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _authInProgress = false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sync Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('🔄 Sync Everything to OneDrive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _syncAll,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Shifts'),
                onPressed: _exportShifts,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.inventory),
                label: const Text('Export Inventory'),
                onPressed: _exportInventory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.backup),
          label: const Text('Backup Database'),
          onPressed: _backupDb,
        ),
      ],
    );
  }

  Widget _buildFilesList() {
    if (_files.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.folder_open),
          title: Text('No files yet — tap "Sync Everything" to upload'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Files in OneDrive (${_files.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...(_files.map((f) {
          final name = f['name'] ?? '';
          final size = f['size'] ?? 0;
          final modified = (f['lastModifiedDateTime'] ?? '').toString().substring(0, 10);
          final webUrl = f['webUrl'] ?? '';
          return Card(
            child: ListTile(
              leading: Icon(
                name.endsWith('.xlsx') ? Icons.table_chart :
                name.endsWith('.db') ? Icons.storage : Icons.insert_drive_file,
                color: name.endsWith('.xlsx') ? Colors.green[700] : Colors.blue[700],
              ),
              title: Text(name, style: const TextStyle(fontSize: 13)),
              subtitle: Text('$modified · ${(size / 1024).toStringAsFixed(0)} KB'),
              trailing: const Icon(Icons.open_in_new, size: 16),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_error ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _error = null),
        ),
      ),
    );
  }
}
