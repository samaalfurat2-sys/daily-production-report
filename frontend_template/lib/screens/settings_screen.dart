import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OneDrive connection status
          Card(
            child: ListTile(
              leading: Icon(
                appState.isConnectedToOneDrive ? Icons.cloud_done : Icons.cloud_off,
                color: appState.isConnectedToOneDrive ? Colors.green : Colors.orange,
              ),
              title: Text(
                appState.isConnectedToOneDrive
                    ? 'OneDrive: Connected'
                    : 'OneDrive: Not Connected',
              ),
              subtitle: Text(
                appState.isConnectedToOneDrive
                    ? 'Data is synced to OneDrive'
                    : 'Connect OneDrive to sync data',
              ),
              trailing: appState.isConnectedToOneDrive
                  ? TextButton(
                      onPressed: () async {
                        await appState.disconnectOneDrive();
                      },
                      child: const Text('Disconnect'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          
          // Language selector
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(t.language),
              subtitle: Text(
                appState.locale?.languageCode == 'ar' ? t.arabic : t.english,
              ),
              trailing: DropdownButton<String>(
                value: appState.locale?.languageCode ?? 'en',
                onChanged: (value) {
                  if (value != null) {
                    appState.setLocale(Locale(value));
                  }
                },
                items: [
                  DropdownMenuItem(value: 'ar', child: Text(t.arabic)),
                  DropdownMenuItem(value: 'en', child: Text(t.english)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // User info
          if (appState.isLoggedIn) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User: \${appState.token}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Roles: \${appState.roles.join(', ')}'),
                    const SizedBox(height: 8),
                    Text(
                      'Warehouse access: \${appState.canSeeWarehouse ? 'Yes' : 'No'}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Logout button
          if (appState.isLoggedIn)
            FilledButton(
              onPressed: () async {
                await appState.logout();
              },
              child: Text(t.signOut),
            ),
        ],
      ),
    );
  }
}
