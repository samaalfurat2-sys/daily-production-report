import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_state.dart';
import 'services/sync_service.dart';
import 'services/background_sync.dart';
import 'services/push_notifications.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

/// Global navigator key – required by PushNotifications for in-app navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase initialisation ──────────────────────────────────────────────
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ── Background sync engine (WorkManager) ────────────────────────────────
  await BackgroundSync.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..loadFromStorage()),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: const ProductionReportApp(),
    ),
  );
}

class ProductionReportApp extends StatelessWidget {
  const ProductionReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Wire push notifications once the user is logged in and navigator is ready.
    if (appState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PushNotifications.initialize(
          serverUrl: appState.serverUrl,
          token: appState.token!,
          navigatorKey: navigatorKey,
        );
      });
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Daily Production Report',
      locale: appState.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: appState.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
