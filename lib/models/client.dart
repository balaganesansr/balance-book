import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Denormalised copy of a client's newest transaction, so list rows can show
/// "last activity" without a query per client.
class LastTxSummary {
  const LastTxSummary({
    required this.id,
    required this.type,
    required this.amount,
    required this.delta,
    required this.note,
  });

  final String id;
  final TxType type;
  final int amount;
  final int delta;
  final String note;

  static LastTxSummary? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['id'] as String?;
    if (id == null) return null;
    return LastTxSummary(
      id: id,
      type: TxTypeX.fromId(map['type'] as String?),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      note: (map['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.id,
    'amount': amount,
    'delta': delta,
    'note': note,
  };
}

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
    required this.avatarColor,
    required this.currentBalance,
    required this.totalCharged,
    required this.totalPaid,
    required this.transactionCount,
    required this.isFavorite,
    required this.status,
    required this.lastTransactionId,
    required this.lastTransaction,
    required this.shareId,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
  });

  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String address;

  /// Free-form notes about the client, never about a specific transaction.
  final String notes;

  /// Hex colour (`#4F46E5`) used for the avatar.
  final String avatarColor;

  /// Integer minor units. Positive = the client owes the user.
  final int currentBalance;
  final int totalCharged;
  final int totalPaid;
  final int transactionCount;

  final bool isFavorite;
  final ClientStatus status;

  /// Newest transaction id. Kept on the client doc so "delete the latest
  /// transaction" can be checked atomically inside a Firestore transaction
  /// (which cannot run queries).
  final String? lastTransactionId;
  final LastTxSummary? lastTransaction;

  /// Random, unguessable key for this client's read-only balance page.
  /// `null` means no link has been issued. Revoking sets it back to `null`.
  final String? shareId;

  bool get isShared => shareId != null && shareId!.isNotEmpty;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivityAt;

  BalanceState get balanceState => BalanceStateX.of(currentBalance);
  bool get isArchived => status == ClientStatus.archived;

  /// Lowercased name. Firestore stores its own copy for server-side ordering;
  /// this getter is what the in-memory sort and search use.
  String get nameLower => name.toLowerCase();

  String get displayCompany => companyName.trim();
  bool get hasPhone => phone.trim().isNotEmpty;

  /// Up to two initials, e.g. "Rahul Sharma" -> "RS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Everything the client search matches against, pre-lowercased.
  String get searchHaystack =>
      '${name.toLowerCase()} ${companyName.toLowerCase()} '
      '${email.toLowerCase()} ${_digits(phone)}';

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String normalisePhoneForSearch(String s) => _digits(s);

  factory Client.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Client(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      companyName: (d['companyName'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      notes: (d['notes'] as String?) ?? '',
      avatarColor: (d['avatarColor'] as String?) ?? '#4F46E5',
      currentBalance: (d['currentBalance'] as num?)?.toInt() ?? 0,
      totalCharged: (d['totalCharged'] as num?)?.toInt() ?? 0,
      totalPaid: (d['totalPaid'] as num?)?.toInt() ?? 0,
      transactionCount: (d['transactionCount'] as num?)?.toInt() ?? 0,
      isFavorite: (d['isFavorite'] as bool?) ?? false,
      status: ClientStatusX.fromId(d['status'] as String?),
      lastTransactionId: d['lastTransactionId'] as String?,
      lastTransaction: LastTxSummary.fromMap(
        (d['lastTransaction'] as Map?)?.cast<String, dynamic>(),
      ),
      shareId: d['shareId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (d['lastActivityAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The editable, non-financial part of a client. Deliberately excludes every
/// balance field so an edit can never move money.
class ClientDraft {
  const ClientDraft({
    this.name = '',
    this.companyName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.avatarColor = '#4F46E5',
  });

  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final String avatarColor;

  factory ClientDraft.fromClient(Client c) => ClientDraft(
    name: c.name,
    companyName: c.companyName,
    phone: c.phone,
    email: c.email,
    address: c.address,
    notes: c.notes,
    avatarColor: c.avatarColor,
  );

  Map<String, dynamic> toProfileMap() => {
    'name': name.trim(),
    'nameLower': name.trim().toLowerCase(),
    'companyName': companyName.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'notes': notes.trim(),
    'avatarColor': avatarColor,
  };
}
