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

/// Whether Firebase was successfully initialized.
bool _firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase initialisation (graceful — app works without it) ────────────
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _firebaseReady = true;
  } catch (e) {
    // Firebase not configured (placeholder google-services.json).
    // Push notifications will be disabled; all other features work normally.
    debugPrint('[Firebase] Skipping Firebase init: $e');
    _firebaseReady = false;
  }

  // ── Background sync engine (WorkManager) ────────────────────────────────
  try {
    await BackgroundSync.initialize();
  } catch (e) {
    debugPrint('[BackgroundSync] Init skipped: $e');
  }

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

    // Wire push notifications only if Firebase is ready and user is logged in.
    if (_firebaseReady && appState.isLoggedIn) {
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
