import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  
  // OneDrive connection state
  bool _showOneDriveFlow = false;
  String _userCode = '';
  String _deviceCode = '';
  String _verificationUri = '';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => appState.setLocale(Locale(value)),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'ar', child: Text(t.arabic)),
              PopupMenuItem(value: 'en', child: Text(t.english)),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _showOneDriveFlow
                    ? _buildOneDriveFlow(appState, t)
                    : _buildLoginForm(appState, t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppState appState, AppLocalizations t) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          
          // OneDrive connection banner
          if (!appState.isConnectedToOneDrive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appState.locale?.languageCode == 'ar'
                              ? '  OneDrive '
                              : 'OneDrive not connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startOneDriveConnection,
                      child: Text(
                        appState.locale?.languageCode == 'ar'
                            ? '  OneDrive'
                            : 'Connect OneDrive',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (appState.isConnectedToOneDrive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appState.locale?.languageCode == 'ar'
                          ? '  OneDrive '
                          : 'OneDrive connected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          TextFormField(
            controller: _username,
            decoration: InputDecoration(labelText: t.username),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: (v) => (v == null || v.trim().isEmpty) ? t.username : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(labelText: t.password),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: (v) => (v == null || v.isEmpty) ? t.password : null,
            onFieldSubmitted: (_) => _doLogin(appState, t),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : () => _doLogin(appState, t),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.signIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOneDriveFlow(AppState appState, AppLocalizations t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Connect OneDrive',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const Text(
          'Step 1: Open this URL in a browser:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SelectableText(
          _verificationUri,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Step 2: Enter this code:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _userCode,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Step 3: After signing in, tap the button below:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _checkOneDriveConnection,
            child: const Text('I completed sign-in'),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showOneDriveFlow = false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _startOneDriveConnection() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final result = await appState.connectOneDrive();
      setState(() {
        _userCode = result['user_code'] ?? '';
        _deviceCode = result['device_code'] ?? '';
        _verificationUri = result['verification_uri'] ?? 'https://microsoft.com/devicelogin';
        _showOneDriveFlow = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkOneDriveConnection() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final success = await appState.pollOneDriveConnection(_deviceCode);
      if (success) {
        setState(() {
          _showOneDriveFlow = false;
        });
      } else {
        setState(() => _error = 'Still waiting... Try again in a few seconds.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _doLogin(AppState appState, AppLocalizations t) async {
    if (!_formKey.currentState!.validate()) return;
    if (!appState.isConnectedToOneDrive) {
      setState(() => _error = 'Please connect OneDrive first');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await appState.login(_username.text.trim(), _password.text);
    } catch (_) {
      setState(() => _error = t.invalidCredentials);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
