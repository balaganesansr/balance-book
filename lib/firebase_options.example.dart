// TEMPLATE. Copy to `firebase_options.dart`, or just run:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// That command writes the real `firebase_options.dart` for your own Firebase
// project and drops `google-services.json` / `GoogleService-Info.plist` into
// place. All three are gitignored, because they belong to your project rather
// than to this source tree.
//
// These are Firebase *client* keys. They identify the project, they do not
// grant access: what a signed-in user may read or write is decided entirely by
// `firestore.rules`. That is why this file is committed while
// `google-services.json` / `GoogleService-Info.plist` are not, because those are
// regenerated per environment.
//
// [DefaultFirebaseOptions.isConfigured] stays as a guard so a fresh clone with
// placeholder values shows the setup screen instead of crashing on a bad key.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the platform the app is running on.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// Whether real credentials have been generated yet.
  static bool get isConfigured => !android.apiKey.startsWith('REPLACE_');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Balance Book targets Android and iOS. Run `flutterfire configure` '
        'again with web enabled if you need it.',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Balance Book is not configured for $defaultTargetPlatform.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'com.example.balanceBook',
  );
}
