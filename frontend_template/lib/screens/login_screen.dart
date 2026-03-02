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
  // FIX: Removed hardcoded admin/Admin1234 defaults — forces users to
  // enter real credentials and avoids accidentally shipping debug creds.
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _serverUrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _serverUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    // Only pre-fill serverUrl from persisted state — never pre-fill credentials.
    if (_serverUrl.text.isEmpty) {
      _serverUrl.text = appState.serverUrl;
    }

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverUrl,
                        decoration: InputDecoration(labelText: t.serverUrl),
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.serverUrl : null,
                      ),
                      const SizedBox(height: 8),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doLogin(AppState appState, AppLocalizations t) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await appState.setServerUrl(_serverUrl.text);
      await appState.login(_username.text.trim(), _password.text);
    } catch (_) {
      setState(() => _error = t.invalidCredentials);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
