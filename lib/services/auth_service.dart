import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/money.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// Firebase Authentication, plus the `users/{uid}` profile document that every
/// other collection hangs off.
///
/// Session persistence is handled by the Firebase SDK itself on mobile. The
/// user stays signed in across app restarts with no extra work.
class AuthService {
  const AuthService();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const LedgerException('Could not create the account.');
      }

      final displayName = name.trim();
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
      await _ensureProfile(user, name: displayName);
    } on FirebaseAuthException catch (e) {
      throw _translate(e);
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      // Covers accounts created before the profile document existed, and any
      // sign-up where the app was killed mid-way.
      if (user != null) await _ensureProfile(user);
    } on FirebaseAuthException catch (e) {
      throw _translate(e);
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _translate(e);
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Creates `users/{uid}` if it is missing. Safe to call on every sign-in.
  Future<void> _ensureProfile(User user, {String? name}) async {
    final ref = Db.user(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'name': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      'photoURL': user.photoURL,
      'currency': Currency.inr.code,
      'paymentDetails': '',
      'portalBaseUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Firebase auth codes are not fit to show a user; these messages are.
  static LedgerException _translate(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'That email address does not look right.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' =>
        'An account already exists with that email. Try signing in instead.',
      'weak-password' => 'Choose a password of at least 6 characters.',
      'operation-not-allowed' =>
        'Email sign-in is not enabled for this project yet.',
      'too-many-requests' =>
        'Too many attempts. Please wait a minute and try again.',
      'network-request-failed' =>
        'No connection. Check your internet and try again.',
      'requires-recent-login' =>
        'For security, please sign in again before making this change.',
      _ => 'Could not complete that request. Please try again.',
    };
    return LedgerException(message, code: e.code);
  }
}
