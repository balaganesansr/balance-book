import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/project.dart';
import 'firestore_refs.dart';
import 'ledger_exception.dart';

/// Projects group a client's transactions. They are labels, not ledgers, so no
/// method here ever reads or writes a balance.
class ProjectService {
  const ProjectService();

  Stream<List<Project>> watchForClient(String uid, String clientId) {
    return Db.projects(uid, clientId)
        .orderBy('nameLower')
        .snapshots()
        .map((s) => s.docs.map(Project.fromDoc).toList(growable: false));
  }

  Future<String> create({
    required String uid,
    required String clientId,
    required String name,
    String note = '',
    String color = '#4F46E5',
  }) async {
    if (name.trim().isEmpty) {
      throw const LedgerException('A project needs a name.');
    }
    final ref = Db.projects(uid, clientId).doc();
    try {
      await ref.set({
        'name': name.trim(),
        'nameLower': name.trim().toLowerCase(),
        'note': note.trim(),
        'color': color,
        'status': ProjectStatus.active.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> update({
    required String uid,
    required String clientId,
    required String projectId,
    required String name,
    required String note,
    required String color,
    required ProjectStatus status,
  }) async {
    if (name.trim().isEmpty) {
      throw const LedgerException('A project needs a name.');
    }
    try {
      await Db.project(uid, clientId, projectId).update({
        'name': name.trim(),
        'nameLower': name.trim().toLowerCase(),
        'note': note.trim(),
        'color': color,
        'status': status.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  Future<void> setStatus({
    required String uid,
    required String clientId,
    required String projectId,
    required ProjectStatus status,
  }) async {
    try {
      await Db.project(uid, clientId, projectId).update({
        'status': status.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw LedgerException.from(e);
    }
  }

  /// Deletes a project and clears the tag from any transaction that used it.
  ///
  /// Only the `projectId` label is cleared. Amounts, types and running
  /// balances are never touched, so removing a project cannot change what a
  /// client owes. Archiving is offered first in the UI for anyone who wants to
  /// keep the grouping intact.
  Future<int> deleteAndUntag({
    required String uid,
    required String clientId,
    required String projectId,
  }) async {
    try {
      var untagged = 0;
      const chunk = 300;

      while (true) {
        final snap = await Db.transactions(uid, clientId)
            .where('projectId', isEqualTo: projectId)
            .limit(chunk)
            .get();
        if (snap.docs.isEmpty) break;

        final batch = Db.fs.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'projectId': null});
        }
        await batch.commit();
        untagged += snap.docs.length;
        if (snap.docs.length < chunk) break;
      }

      await Db.project(uid, clientId, projectId).delete();
      return untagged;
    } catch (e) {
      throw LedgerException.from(e);
    }
  }
}
