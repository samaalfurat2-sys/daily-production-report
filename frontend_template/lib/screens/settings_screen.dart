import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final serverController = TextEditingController(text: appState.serverUrl);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(title: Text(t.language)),
            SegmentedButton<Locale>(
              segments: [
                ButtonSegment(value: const Locale('ar'), label: Text(t.arabic)),
                ButtonSegment(value: const Locale('en'), label: Text(t.english)),
              ],
              selected: {appState.locale ?? const Locale('ar')},
              onSelectionChanged: (s) => appState.setLocale(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: serverController,
              decoration: InputDecoration(labelText: t.serverUrl, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => appState.setServerUrl(serverController.text),
              child: Text(t.save),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => appState.logout(),
              icon: const Icon(Icons.logout),
              label: Text(t.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
