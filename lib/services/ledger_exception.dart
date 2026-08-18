/// A failure the user can actually act on, with a message safe to show as-is.
///
/// Raw `FirebaseException` codes ("permission-denied", "unavailable") are
/// translated here so no screen ever surfaces a Firebase error string.
class LedgerException implements Exception {
  const LedgerException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  static const offline = LedgerException(
    'You appear to be offline. Charges and payments need a connection so the '
    'balance can be saved safely. Nothing has been recorded.',
    code: 'unavailable',
  );

  /// Turns any thrown object into something worth showing a user.
  static LedgerException from(Object error) {
    if (error is LedgerException) return error;

    final text = error.toString();
    final code = _codeOf(text);

    return switch (code) {
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' => offline,
      'permission-denied' => const LedgerException(
        'You do not have permission to change this. Try signing out and back in.',
        code: 'permission-denied',
      ),
      'not-found' => const LedgerException(
        'That record no longer exists. It may have been deleted on another device.',
        code: 'not-found',
      ),
      'aborted' || 'failed-precondition' => const LedgerException(
        'Someone changed this at the same time. Nothing was saved, please try again.',
        code: 'aborted',
      ),
      'resource-exhausted' => const LedgerException(
        'Too many requests right now. Please wait a moment and try again.',
        code: 'resource-exhausted',
      ),
      _ => const LedgerException(
        'Something went wrong and nothing was saved. Please try again.',
      ),
    };
  }

  static String? _codeOf(String text) {
    final match = RegExp(r'\[(?:cloud_firestore/|firebase_auth/)?([a-z-]+)\]')
        .firstMatch(text);
    return match?.group(1);
  }
}
