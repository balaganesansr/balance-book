import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;
typedef JsonDoc = DocumentSnapshot<Json>;
typedef JsonQuery = Query<Json>;

/// Single place where Firestore paths are built.
///
/// Layout:
/// ```
/// users/{uid}
/// users/{uid}/clients/{clientId}
/// users/{uid}/clients/{clientId}/projects/{projectId}
/// users/{uid}/clients/{clientId}/transactions/{transactionId}
/// ```
/// Everything a user owns lives under their own `users/{uid}` document, which
/// is what makes the security rules a one-liner: the uid in the path must equal
/// the uid on the request.
class Db {
  const Db._();

  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  static CollectionReference<Json> get users => fs.collection('users');

  static DocumentReference<Json> user(String uid) => users.doc(uid);

  static CollectionReference<Json> clients(String uid) =>
      user(uid).collection('clients');

  static DocumentReference<Json> client(String uid, String clientId) =>
      clients(uid).doc(clientId);

  static CollectionReference<Json> projects(String uid, String clientId) =>
      client(uid, clientId).collection('projects');

  static DocumentReference<Json> project(
    String uid,
    String clientId,
    String projectId,
  ) => projects(uid, clientId).doc(projectId);

  static CollectionReference<Json> transactions(String uid, String clientId) =>
      client(uid, clientId).collection('transactions');

  static DocumentReference<Json> transaction(
    String uid,
    String clientId,
    String transactionId,
  ) => transactions(uid, clientId).doc(transactionId);

  /// Read-only balance pages, keyed by an unguessable share id.
  ///
  /// Deliberately **top-level**, not nested under `users/{uid}`: it is the one
  /// place an unauthenticated reader is allowed, and keeping it outside the
  /// private tree makes that boundary obvious in both the code and the rules.
  static CollectionReference<Json> get publicLedgers =>
      fs.collection('publicLedgers');

  static DocumentReference<Json> publicLedger(String shareId) =>
      publicLedgers.doc(shareId);

  /// Every transaction the signed-in user owns, across all clients.
  ///
  /// Callers **must** constrain this with `where('userId', isEqualTo: uid)`,
  /// the security rules reject anything broader, and the composite indexes in
  /// `firestore.indexes.json` are built around that filter.
  static JsonQuery get allTransactions => fs.collectionGroup('transactions');
}
