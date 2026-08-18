import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';
import 'services/prefs_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Without real credentials, say so plainly rather than crashing in native
  // code on a placeholder API key.
  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const FirebaseSetupApp());
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('Firebase failed to start: $error\n$stack');
    runApp(FirebaseSetupApp(error: error));
    return;
  }

  // Offline persistence lets the app open and show the last synced figures
  // without a connection. Writes still require the network. See
  // TransactionService, where every balance change runs inside a Firestore
  // transaction so the ledger and the balance can never diverge.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await PrefsService.create();
  final notifications = NotificationService();
  await notifications.initialize();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const BalanceBookApp(),
    ),
  );
}
