import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// The signed-in user's own `users/{uid}` document.
class ProfileService {
  const ProfileService();

  Stream<UserProfile?> watch(String uid) {
    return Db.user(uid)
        .snapshots()
        .map((d) => d.exists ? UserProfile.fromDoc(d) : null);
  }

  Future<void> update({
    required String uid,
    String? name,
    String? currencyCode,
    String? paymentDetails,
    String? portalBaseUrl,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) data['name'] = name.trim();
    if (currencyCode != null) data['currency'] = currencyCode;
    if (paymentDetails != null) data['paymentDetails'] = paymentDetails.trim();
    if (portalBaseUrl != null) {
      // Stored without a trailing slash so link building stays predictable.
      data['portalBaseUrl'] =
          portalBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    try {
      await Db.user(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw LedgerException.from(e);
    }
  }
}
