import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A single, immutable-by-convention entry in a client's ledger.
///
/// Named `AppTransaction` to avoid colliding with Firestore's `Transaction`.
///
/// Invariants every write must preserve:
///  * [amount] is always **positive**. It is what the user typed.
///  * [delta] is the **signed** effect on the balance and is the only thing the
///    balance is derived from. A charge is `+amount`, a payment is `-amount`.
///  * [runningBalance] is the client balance immediately *after* this entry.
///  * [prevTransactionId] chains entries newest-to-oldest, which lets the
///    newest entry be removed atomically without re-reading the whole history.
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.projectId,
    required this.type,
    required this.amount,
    required this.delta,
    required this.runningBalance,
    required this.note,
    required this.paymentMethod,
    required this.prevTransactionId,
    required this.reversesId,
    required this.reversedById,
    required this.isReversed,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    required this.editedAt,
  });

  final String id;

  /// Owner uid, duplicated onto every transaction so the global Activity feed
  /// can use a collection-group query that security rules can scope.
  final String userId;
  final String clientId;

  /// Optional grouping label. `null` means "General".
  final String? projectId;

  final TxType type;
  final int amount;
  final int delta;
  final int runningBalance;

  final String note;
  final String paymentMethod;

  final String? prevTransactionId;
  final String? reversesId;
  final String? reversedById;
  final bool isReversed;

  final DateTime? createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime? editedAt;

  bool get increasesBalance => delta > 0;
  bool get isReversal => type == TxType.reversal;
  bool get wasEdited => editedAt != null;

  /// True while the write is still in flight. `createdAt` is a server
  /// timestamp and stays null until the server confirms it.
  bool get isPending => createdAt == null;

  /// Best-effort timestamp for sorting/grouping a not-yet-confirmed write.
  DateTime get effectiveDate => createdAt ?? DateTime.now();

  /// `+₹2,000` / `−₹5,000` prefix character.
  String get signPrefix => delta >= 0 ? '+' : '−';

  factory AppTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppTransaction(
      id: doc.id,
      userId: (d['userId'] as String?) ?? '',
      clientId: (d['clientId'] as String?) ?? doc.reference.parent.parent?.id ?? '',
      projectId: d['projectId'] as String?,
      type: TxTypeX.fromId(d['type'] as String?),
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      delta: (d['delta'] as num?)?.toInt() ?? 0,
      runningBalance: (d['runningBalance'] as num?)?.toInt() ?? 0,
      note: (d['note'] as String?) ?? '',
      paymentMethod: (d['paymentMethod'] as String?) ?? '',
      prevTransactionId: d['prevTransactionId'] as String?,
      reversesId: d['reversesId'] as String?,
      reversedById: d['reversedById'] as String?,
      isReversed: (d['isReversed'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: (d['createdBy'] as String?) ?? '',
      createdByName: (d['createdByName'] as String?) ?? '',
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// What the user filled in on an Add Charge / Record Payment form.
///
/// The service, not the caller, turns this into a signed [AppTransaction.delta],
/// so there is exactly one place where the sign of money is decided.
class TxDraft {
  const TxDraft({
    required this.type,
    required this.amount,
    this.note = '',
    this.paymentMethod = '',
    this.projectId,
    this.increase = true,
  });

  /// Never `reversal`. Reversals are produced by the service, not by a form.
  final TxType type;

  /// Always positive minor units.
  final int amount;
  final String note;
  final String paymentMethod;
  final String? projectId;

  /// Direction for [TxType.adjustment] only. Ignored for other types.
  final bool increase;

  /// The signed effect this draft will have on the client's balance.
  int get delta => switch (type) {
    TxType.opening => amount,
    TxType.charge => amount,
    TxType.payment => -amount,
    TxType.adjustment => increase ? amount : -amount,
    TxType.reversal => throw StateError(
      'Reversals are created by TransactionService.reverse(), not from a draft.',
    ),
  };
}
