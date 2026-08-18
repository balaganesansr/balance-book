import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/client.dart';
import '../models/enums.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// Reads and non-financial writes for clients.
///
/// The one exception is [create], which may seed an opening balance, and even
/// that writes a real opening *transaction* alongside it, so the balance is
/// still explained by the ledger rather than set by hand.
class ClientService {
  const ClientService();

  /// Every client the user owns, ordered by name.
  ///
  /// Loading the whole list up front is deliberate: it makes search, filtering
  /// and the dashboard totals instant and query-free. A single freelancer's
  /// client list is small enough that this is cheaper than many narrow queries.
  Stream<List<Client>> watchAll(String uid) {
    return Db.clients(uid)
        .orderBy('nameLower')
        .snapshots()
        .map((s) => s.docs.map(Client.fromDoc).toList(growable: false));
  }

  Stream<Client?> watchOne(String uid, String clientId) {
    return Db.client(uid, clientId)
        .snapshots()
        .map((d) => d.exists ? Client.fromDoc(d) : null);
  }

  Future<Client?> fetchOne(String uid, String clientId) async {
    final doc = await Db.client(uid, clientId).get();
    return doc.exists ? Client.fromDoc(doc) : null;
  }

  /// Creates a client and, when [openingBalance] is non-zero, the matching
  /// opening transaction, in one atomic batch.
  ///
  /// The balance is never "just set": even at creation it is the result of a
  /// recorded transaction, so the history explains the number from day one.
  /// A negative [openingBalance] is allowed and records an advance the client
  /// has already paid.
  Future<String> create({
    required String uid,
    required ClientDraft draft,
    required int openingBalance,
    required String actorName,
  }) async {
    if (draft.name.trim().isEmpty) {
      throw const LedgerException('A client needs a name.');
    }

    final clientRef = Db.clients(uid).doc();
    final hasOpening = openingBalance != 0;
    final txRef = hasOpening ? Db.transactions(uid, clientRef.id).doc() : null;

    final batch = Db.fs.batch();

    batch.set(clientRef, {
      ...draft.toProfileMap(),
      'currentBalance': openingBalance,
      'totalCharged': openingBalance > 0 ? openingBalance : 0,
      'totalPaid': openingBalance < 0 ? -openingBalance : 0,
      'transactionCount': hasOpening ? 1 : 0,
      'isFavorite': false,
      'status': ClientStatus.active.id,
      'lastTransactionId': txRef?.id,
      'lastTransaction': txRef == null
          ? null
          : {
              'id': txRef.id,
              'type': TxType.opening.id,
              'amount': openingBalance.abs(),
              'delta': openingBalance,
              'note': 'Opening balance',
            },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    if (txRef != null) {
      batch.set(txRef, {
        'userId': uid,
        'clientId': clientRef.id,
        'projectId': null,
        'type': TxType.opening.id,
        'amount': openingBalance.abs(),
        'delta': openingBalance,
        'runningBalance': openingBalance,
        'note': 'Opening balance',
        'paymentMethod': '',
        'prevTransactionId': null,
        'reversesId': null,
        'reversedById': null,
        'isReversed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'createdByName': actorName,
        'editedAt': null,
      });
    }

    try {
      await batch.commit();
      return clientRef.id;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Updates the contact details only.
  ///
  /// [ClientDraft] carries no balance fields, so an edit here structurally
  /// cannot touch the ledger.
  Future<void> updateProfile({
    required String uid,
    required String clientId,
    required ClientDraft draft,
  }) async {
    if (draft.name.trim().isEmpty) {
      throw const LedgerException('A client needs a name.');
    }
    try {
      await Db.client(uid, clientId).update({
        ...draft.toProfileMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> setFavorite({
    required String uid,
    required String clientId,
    required bool isFavorite,
  }) async {
    try {
      await Db.client(uid, clientId).update({
        'isFavorite': isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> setStatus({
    required String uid,
    required String clientId,
    required ClientStatus status,
  }) async {
    try {
      await Db.client(uid, clientId).update({
        'status': status.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Deletes a client and everything under it.
  ///
  /// Destructive and irreversible. Archiving is the recommended path and is
  /// what the UI offers first. Subcollections are removed in chunks because
  /// Firestore has no recursive delete on the client SDK and a batch caps at
  /// 500 writes.
  Future<void> deleteForever({
    required String uid,
    required String clientId,
  }) async {
    try {
      await _deleteCollection(Db.transactions(uid, clientId));
      await _deleteCollection(Db.projects(uid, clientId));
      await Db.client(uid, clientId).delete();
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  static Future<void> _deleteCollection(CollectionReference<Json> ref) async {
    const chunk = 300;
    while (true) {
      final snap = await ref.limit(chunk).get();
      if (snap.docs.isEmpty) return;
      final batch = Db.fs.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < chunk) return;
    }
  }
}
