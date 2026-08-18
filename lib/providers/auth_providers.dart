import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money.dart';
import '../models/user_profile.dart';
import '../services/firestore_refs.dart';
import 'app_providers.dart';

/// The Firebase session. Emits on sign-in, sign-out and token refresh, and is
/// restored automatically on app start.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// `null` while signed out or while the first auth state is still loading.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// Throws if read outside the signed-in part of the app. Screens behind the
/// auth guard can rely on it, which avoids null checks in every provider.
final requireUidProvider = Provider<String>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('requireUidProvider read while signed out');
  }
  return uid;
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileServiceProvider).watch(uid);
});

/// Display currency. Falls back to INR until the profile has loaded, so the UI
/// never flashes a wrong symbol.
final currencyProvider = Provider<Currency>(
  (ref) => ref.watch(userProfileProvider).value?.currency ?? Currency.inr,
);

/// Name recorded as "created by" on new transactions.
final actorNameProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  if (profile != null && profile.name.trim().isNotEmpty) return profile.name;

  final user = ref.watch(authStateProvider).value;
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  return user?.email ?? 'You';
});

/// Whether Firestore is currently serving from its local cache.
///
/// Derived from snapshot metadata on the user's own document rather than from
/// a connectivity plugin: what matters here is whether *Firestore* is reachable,
/// not whether the device claims to have a network.
final isOfflineProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return Db.user(uid)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.isFromCache);
});
