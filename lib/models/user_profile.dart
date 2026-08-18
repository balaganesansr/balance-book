import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/money.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    required this.currencyCode,
    required this.paymentDetails,
    required this.portalBaseUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoURL;

  /// Display currency only. Stored amounts are always integer minor units and
  /// are never rewritten when this changes.
  final String currencyCode;

  /// Optional bank/UPI details appended to reminder messages.
  final String paymentDetails;

  /// Where `ledger.html` is hosted, e.g. `https://your-project.web.app`.
  /// Share links are built from this; empty means links cannot be formed yet.
  final String portalBaseUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Currency get currency => Currency.fromCode(currencyCode);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      name: (d['name'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      photoURL: d['photoURL'] as String?,
      currencyCode: (d['currency'] as String?) ?? Currency.inr.code,
      paymentDetails: (d['paymentDetails'] as String?) ?? '',
      portalBaseUrl: (d['portalBaseUrl'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  UserProfile copyWith({
    String? name,
    String? currencyCode,
    String? paymentDetails,
    String? portalBaseUrl,
  }) => UserProfile(
    uid: uid,
    name: name ?? this.name,
    email: email,
    photoURL: photoURL,
    currencyCode: currencyCode ?? this.currencyCode,
    paymentDetails: paymentDetails ?? this.paymentDetails,
    portalBaseUrl: portalBaseUrl ?? this.portalBaseUrl,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
