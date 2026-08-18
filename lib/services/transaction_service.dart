import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_transaction.dart';
import '../models/enums.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// All writes that can move a client's balance.
///
/// Every one of them runs inside a Firestore transaction that reads the client
/// document first, so the stored `currentBalance` and the ledger can never
/// drift apart, even if two devices write at the same moment.
///
/// Nothing outside this class is allowed to write `currentBalance`.
class TransactionService {
  const TransactionService();

  /// Records a charge, payment, adjustment or opening balance.
  ///
  /// Returns the id of the new transaction. Throws [LedgerException] with a
  /// user-readable message on failure, so the caller can show it directly.
  Future<String> add({
    required String uid,
    required String clientId,
    required TxDraft draft,
    required String actorName,
  }) async {
    if (draft.amount <= 0) {
      throw const LedgerException('Enter an amount greater than zero.');
    }
    if (draft.type == TxType.reversal) {
      throw const LedgerException('Use reverse() to create a reversal.');
    }

    final clientRef = Db.client(uid, clientId);
    final txRef = Db.transactions(uid, clientId).doc();

    try {
      await Db.fs.runTransaction((t) async {
        final snap = await t.get(clientRef);
        if (!snap.exists) {
          throw const LedgerException('That client no longer exists.');
        }
        final data = snap.data() ?? const <String, dynamic>{};
        final balance = _int(data['currentBalance']);
        final delta = draft.delta;
        final newBalance = balance + delta;

        t.set(txRef, {
          'userId': uid,
          'clientId': clientId,
          'projectId': draft.projectId,
          'type': draft.type.id,
          'amount': draft.amount,
          'delta': delta,
          'runningBalance': newBalance,
          'note': draft.note.trim(),
          'paymentMethod': draft.paymentMethod.trim(),
          'prevTransactionId': data['lastTransactionId'],
          'reversesId': null,
          'reversedById': null,
          'isReversed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'createdByName': actorName,
          'editedAt': null,
        });

        t.update(clientRef, {
          ..._balanceFields(
            data: data,
            newBalance: newBalance,
            chargedDelta: delta > 0 ? delta : 0,
            paidDelta: delta < 0 ? -delta : 0,
            countDelta: 1,
          ),
          'lastTransactionId': txRef.id,
          'lastTransaction': {
            'id': txRef.id,
            'type': draft.type.id,
            'amount': draft.amount,
            'delta': delta,
            'note': draft.note.trim(),
          },
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return txRef.id;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Cancels the effect of [original] by writing a compensating entry.
  ///
  /// History is preserved: the original stays exactly as recorded and is only
  /// flagged `isReversed`, while the new entry points back at it. This is the
  /// default correction path. Permanent deletion is deliberately limited to
  /// the newest entry (see [deleteLatest]).
  Future<String> reverse({
    required String uid,
    required String clientId,
    required AppTransaction original,
    required String actorName,
    String? note,
  }) async {
    if (original.isReversed) {
      throw const LedgerException('This transaction has already been reversed.');
    }
    if (original.isReversal) {
      throw const LedgerException('A reversal cannot itself be reversed.');
    }

    final clientRef = Db.client(uid, clientId);
    final originalRef = Db.transaction(uid, clientId, original.id);
    final txRef = Db.transactions(uid, clientId).doc();

    try {
      await Db.fs.runTransaction((t) async {
        // Firestore requires every read to happen before any write.
        final clientSnap = await t.get(clientRef);
        final originalSnap = await t.get(originalRef);

        if (!clientSnap.exists) {
          throw const LedgerException('That client no longer exists.');
        }
        if (!originalSnap.exists) {
          throw const LedgerException('That transaction no longer exists.');
        }

        final originalData = originalSnap.data() ?? const <String, dynamic>{};
        if (originalData['isReversed'] == true) {
          throw const LedgerException(
            'This transaction was already reversed on another device.',
          );
        }

        final data = clientSnap.data() ?? const <String, dynamic>{};
        final balance = _int(data['currentBalance']);
        final originalDelta = _int(originalData['delta']);
        final delta = -originalDelta;
        final newBalance = balance + delta;
        final amount = originalDelta.abs();
        final originalType = TxTypeX.fromId(originalData['type'] as String?);

        final reversalNote = (note == null || note.trim().isEmpty)
            ? 'Reversal of ${originalType.label.toLowerCase()}'
            : note.trim();

        t.set(txRef, {
          'userId': uid,
          'clientId': clientId,
          'projectId': originalData['projectId'],
          'type': TxType.reversal.id,
          'amount': amount,
          'delta': delta,
          'runningBalance': newBalance,
          'note': reversalNote,
          'paymentMethod': '',
          'prevTransactionId': data['lastTransactionId'],
          'reversesId': original.id,
          'reversedById': null,
          'isReversed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'createdByName': actorName,
          'editedAt': null,
        });

        t.update(originalRef, {
          'isReversed': true,
          'reversedById': txRef.id,
        });

        // Undo the original's contribution to the lifetime totals rather than
        // adding to the opposite bucket, so "total charged" stays truthful.
        t.update(clientRef, {
          ..._balanceFields(
            data: data,
            newBalance: newBalance,
            chargedDelta: originalDelta > 0 ? -amount : 0,
            paidDelta: originalDelta < 0 ? -amount : 0,
            countDelta: 1,
          ),
          'lastTransactionId': txRef.id,
          'lastTransaction': {
            'id': txRef.id,
            'type': TxType.reversal.id,
            'amount': amount,
            'delta': delta,
            'note': reversalNote,
          },
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return txRef.id;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Permanently removes [tx], allowed **only** while it is still the newest
  /// entry for the client.
  ///
  /// That restriction is what makes deletion safe: no later entry's
  /// `runningBalance` can be invalidated, so nothing needs recomputing. The
  /// check runs against `lastTransactionId` *inside* the Firestore transaction,
  /// so a race with another device fails cleanly instead of corrupting the
  /// ledger. Anything older must be corrected with [reverse].
  ///
  /// [previous] must be the entry this one superseded (`tx.prevTransactionId`)
  /// so the client's "last transaction" summary can be restored.
  Future<void> deleteLatest({
    required String uid,
    required String clientId,
    required AppTransaction tx,
    required AppTransaction? previous,
  }) async {
    if (tx.prevTransactionId != null &&
        (previous == null || previous.id != tx.prevTransactionId)) {
      throw const LedgerException(
        'Could not load the preceding transaction. Please reopen the client '
        'and try again.',
      );
    }
    if (tx.isReversed) {
      throw const LedgerException(
        'This transaction has been reversed, so it is no longer the latest '
        'entry. Delete the reversal first.',
      );
    }

    final clientRef = Db.client(uid, clientId);
    final txRef = Db.transaction(uid, clientId, tx.id);

    try {
      await Db.fs.runTransaction((t) async {
        final clientSnap = await t.get(clientRef);
        if (!clientSnap.exists) {
          throw const LedgerException('That client no longer exists.');
        }
        final data = clientSnap.data() ?? const <String, dynamic>{};

        if (data['lastTransactionId'] != tx.id) {
          throw const LedgerException(
            'This is no longer the latest transaction, so deleting it would '
            'invalidate the balances recorded after it. Reverse it instead.',
          );
        }

        final balance = _int(data['currentBalance']);
        final newBalance = balance - tx.delta;

        // Deleting a reversal frees the entry it compensated for, so that one
        // becomes correctable again.
        if (tx.isReversal && tx.reversesId != null) {
          t.update(Db.transaction(uid, clientId, tx.reversesId!), {
            'isReversed': false,
            'reversedById': null,
          });
        }

        t.delete(txRef);

        t.update(clientRef, {
          ..._balanceFields(
            data: data,
            newBalance: newBalance,
            chargedDelta: tx.delta > 0 ? -tx.delta : 0,
            paidDelta: tx.delta < 0 ? tx.delta : 0,
            countDelta: -1,
          ),
          'lastTransactionId': previous?.id,
          'lastTransaction': previous == null
              ? null
              : {
                  'id': previous.id,
                  'type': previous.type.id,
                  'amount': previous.amount,
                  'delta': previous.delta,
                  'note': previous.note,
                },
          'lastActivityAt': previous?.createdAt == null
              ? data['createdAt']
              : Timestamp.fromDate(previous!.createdAt!),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Edits only the descriptive parts of an entry.
  ///
  /// Amount and type are intentionally not editable: changing either would
  /// silently invalidate every `runningBalance` recorded afterwards. A wrong
  /// amount is corrected with [reverse] plus a fresh entry.
  Future<void> editDetails({
    required String uid,
    required String clientId,
    required String transactionId,
    required String note,
    required String paymentMethod,
    String? projectId,
  }) async {
    try {
      await Db.transaction(uid, clientId, transactionId).update({
        'note': note.trim(),
        'paymentMethod': paymentMethod.trim(),
        'projectId': projectId,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Live ledger for one client, newest first.
  Stream<List<AppTransaction>> watchForClient(String uid, String clientId) {
    return Db.transactions(uid, clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live feed across every client, newest first.
  ///
  /// Constrained by `userId` so it matches both the security rules and the
  /// composite indexes in `firestore.indexes.json`.
  Stream<List<AppTransaction>> watchAll(
    String uid, {
    int limit = 200,
    TxType? type,
    DateTime? from,
    DateTime? to,
  }) {
    JsonQuery query = Db.allTransactions.where('userId', isEqualTo: uid);
    if (type != null) query = query.where('type', isEqualTo: type.id);
    if (from != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(to));
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapDocs);
  }

  static List<AppTransaction> _mapDocs(QuerySnapshot<Json> snap) =>
      snap.docs.map(AppTransaction.fromDoc).toList(growable: false);

  /// Balance and lifetime-total fields shared by every mutation, clamped so a
  /// bad write can never leave a negative lifetime total behind.
  static Json _balanceFields({
    required Json data,
    required int newBalance,
    required int chargedDelta,
    required int paidDelta,
    required int countDelta,
  }) {
    final charged = _int(data['totalCharged']) + chargedDelta;
    final paid = _int(data['totalPaid']) + paidDelta;
    final count = _int(data['transactionCount']) + countDelta;
    return {
      'currentBalance': newBalance,
      'totalCharged': charged < 0 ? 0 : charged,
      'totalPaid': paid < 0 ? 0 : paid,
      'transactionCount': count < 0 ? 0 : count,
    };
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;
}
