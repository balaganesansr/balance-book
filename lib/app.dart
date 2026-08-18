import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/feedback.dart';
import 'providers/settings_providers.dart';
import 'router.dart';

class BalanceBookApp extends ConsumerWidget {
  const BalanceBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Balance Book',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppToast.messengerKey,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        // Cap text scaling so a very large system font cannot push a balance
        // out of its card, while still honouring the user's preference.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Shown when Firebase credentials have not been generated yet.
///
/// A blunt, actionable screen beats a cryptic native crash on a placeholder
/// API key.
class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balance Book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 40),
                    const SizedBox(height: 18),
                    Text(
                      'Connect a Firebase project',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Balance Book stores your clients and transactions in '
                      'Cloud Firestore, so it needs a Firebase project of your '
                      'own before it can start.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    _Step(
                      number: 1,
                      text:
                          'Create a project at console.firebase.google.com and '
                          'enable Email/Password sign-in plus Cloud Firestore.',
                    ),
                    _Step(
                      number: 2,
                      text: 'dart pub global activate flutterfire_cli',
                      mono: true,
                    ),
                    _Step(
                      number: 3,
                      text: 'flutterfire configure',
                      mono: true,
                    ),
                    _Step(
                      number: 4,
                      text:
                          'firebase deploy --only firestore:rules,firestore:indexes',
                      mono: true,
                    ),
                    _Step(number: 5, text: 'Restart the app.'),
                    if (error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$error',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.mono = false});

  final int number;
  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: mono
                  ? Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
