import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_transaction.dart';
import '../models/client.dart';
import '../models/enums.dart';
import '../models/project.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// Publishes a read-only copy of a client's ledger to a link they can open
/// without an account.
///
/// ## Why a mirror rather than opening up the real data
///
/// Everything under `users/{uid}` is readable only by its owner, and that stays
/// true. Instead, a **separate top-level document** holds a snapshot of exactly
/// what the client is allowed to see. Nothing else is reachable from the link:
/// no phone number, no email, no address, and none of the private notes kept
/// about them.
///
/// ## Why the link is safe
///
/// The share id is 24 characters from a 56-character alphabet, about 139 bits
/// of entropy from a cryptographic RNG, so it cannot be guessed or brute
/// forced. Just as important, the security rules allow `get` on a single
/// document but forbid `list`, so nobody can enumerate the collection to
/// discover other clients' links.
///
/// The link is still a bearer token: anyone holding it can read that one
/// client's balance. That is what [revoke] is for. It deletes the snapshot and
/// clears the id, and the link dies immediately.
class PortalService {
  const PortalService();

  /// Most recent entries copied into a snapshot. Firestore caps a document at
  /// 1 MiB; this stays far below it while covering more history than any client
  /// is likely to scroll.
  static const historyLimit = 200;

  /// Ambiguous glyphs (0/O, 1/l/I) are excluded so an id can be read aloud or
  /// retyped without confusion.
  static const _alphabet =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _idLength = 24;

  static String generateShareId() {
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        _idLength,
        (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
      ),
    );
  }

  /// Issues a link for [clientId] and publishes the first snapshot.
  ///
  /// Returns the share id. Calling this on an already-shared client reuses the
  /// existing id rather than invalidating a link the client may already have.
  Future<String> enable({
    required String uid,
    required String clientId,
    required String currencyCode,
  }) async {
    try {
      final snap = await Db.client(uid, clientId).get();
      if (!snap.exists) {
        throw const LedgerException('That client no longer exists.');
      }

      final existing = (snap.data() ?? const {})['shareId'] as String?;
      final shareId = (existing != null && existing.isNotEmpty)
          ? existing
          : generateShareId();

      await Db.client(uid, clientId).update({
        'shareId': shareId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await sync(uid: uid, clientId: clientId, currencyCode: currencyCode);
      return shareId;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Kills the link. The snapshot is deleted, so the page stops resolving
  /// immediately rather than serving stale figures.
  Future<void> revoke({
    required String uid,
    required String clientId,
    required String shareId,
  }) async {
    try {
      await Db.publicLedger(shareId).delete();
      await Db.client(uid, clientId).update({
        'shareId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Rewrites the snapshot from current data. No-op when the client has no link.
  ///
  /// Called after anything that changes what the client would see. Failures are
  /// swallowed deliberately: a stale share page must never be the reason a
  /// charge or payment appears to fail. [syncQuietly] is the fire-and-forget
  /// wrapper used from UI code.
  Future<void> sync({
    required String uid,
    required String clientId,
    required String currencyCode,
  }) async {
    final clientSnap = await Db.client(uid, clientId).get();
    if (!clientSnap.exists) return;

    final client = Client.fromDoc(clientSnap);
    if (!client.isShared) return;

    final results = await Future.wait([
      Db.transactions(uid, clientId)
          .orderBy('createdAt', descending: true)
          .limit(historyLimit)
          .get(),
      Db.projects(uid, clientId).get(),
    ]);

    final transactions = (results[0])
        .docs
        .map(AppTransaction.fromDoc)
        .toList(growable: false);
    final projects = (results[1])
        .docs
        .map(Project.fromDoc)
        .toList(growable: false);

    await Db.publicLedger(client.shareId!).set(
      buildSnapshot(
        uid: uid,
        client: client,
        transactions: transactions,
        projects: projects,
        currencyCode: currencyCode,
      ),
    );
  }

  /// Fire-and-forget [sync]. Never throws.
  void syncQuietly({
    required String uid,
    required String clientId,
    required String currencyCode,
  }) {
    unawaited(
      sync(uid: uid, clientId: clientId, currencyCode: currencyCode).catchError(
        (Object error) {
          debugPrint('Share page sync failed for $clientId: $error');
        },
      ),
    );
  }

  /// Builds the public document.
  ///
  /// This is the whole privacy boundary, so it is written as an explicit
  /// allow-list. Read it as "these fields and nothing else": no phone, no
  /// email, no address, and none of the private notes kept about the client.
  @visibleForTesting
  static Json buildSnapshot({
    required String uid,
    required Client client,
    required List<AppTransaction> transactions,
    required List<Project> projects,
    required String currencyCode,
    /// Sentinel written to `updatedAt`. Production passes
    /// `FieldValue.serverTimestamp()`; tests pass a plain value so the whole
    /// payload can be asserted without a Firebase binding.
    Object? updatedAt,
  }) {
    final projectsById = {for (final p in projects) p.id: p};
    final projectRows = projectBreakdown(transactions, projects);

    return {
      // Needed by the security rules to prove who may overwrite this document.
      // A uid is an opaque identifier and grants no access on its own.
      'userId': uid,
      'clientId': client.id,
      'clientName': client.name,
      'companyName': client.companyName,
      'currency': currencyCode,
      'currentBalance': client.currentBalance,
      'totalCharged': client.totalCharged,
      'totalPaid': client.totalPaid,
      'transactionCount': client.transactionCount,
      'projects': projectRows,
      'transactions': [
        for (final tx in transactions)
          {
            'type': tx.type.id,
            'amount': tx.amount,
            'delta': tx.delta,
            'runningBalance': tx.runningBalance,
            'note': tx.note,
            'paymentMethod': tx.paymentMethod,
            'projectName': projectsById[tx.projectId]?.name,
            'isReversed': tx.isReversed,
            'createdAt': tx.createdAt == null
                ? null
                : Timestamp.fromDate(tx.createdAt!),
          },
      ],
      'historyTruncated': transactions.length >= historyLimit,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }
}

/// Per-project figures, computed from the transactions tagged to each one.
///
/// Projects hold no balance of their own, they are labels. Everything here is
/// derived on the way out, which is why renaming or deleting a project can
/// never change what a client owes.
@visibleForTesting
List<Json> projectBreakdown(
  List<AppTransaction> transactions,
  List<Project> projects,
) {
  final projectsById = {for (final p in projects) p.id: p};

  final totals = <String?, _ProjectTotals>{};
  for (final tx in transactions) {
    totals.putIfAbsent(tx.projectId, _ProjectTotals.new).add(tx.delta);
  }

  final rows = <Json>[];
  for (final entry in totals.entries) {
    // A tag pointing at a deleted project falls back to "General" rather than
    // leaking a dangling id.
    final project = entry.key == null ? null : projectsById[entry.key];
    rows.add({
      'id': project?.id,
      'name': project?.name ?? 'General',
      'pending': entry.value.net,
      'charged': entry.value.charged,
      'paid': entry.value.paid,
      'entries': entry.value.count,
    });
  }
  rows.sort((a, b) => (b['pending'] as int).compareTo(a['pending'] as int));
  return rows;
}

class _ProjectTotals {
  int charged = 0;
  int paid = 0;
  int count = 0;

  int get net => charged - paid;

  void add(int delta) {
    if (delta > 0) {
      charged += delta;
    } else {
      paid += -delta;
    }
    count++;
  }
}
