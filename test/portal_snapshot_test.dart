import 'package:balance_book/models/app_transaction.dart';
import 'package:balance_book/models/client.dart';
import 'package:balance_book/models/enums.dart';
import 'package:balance_book/models/project.dart';
import 'package:balance_book/services/portal_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The snapshot published to a client's share link is the entire privacy
/// boundary of that feature, so it is asserted directly rather than inferred
/// from the UI.

Client client({
  int balance = 1700000,
  int charged = 2200000,
  int paid = 500000,
}) => Client(
  id: 'c1',
  name: 'Rahul Sharma',
  companyName: 'ABC Agency',
  // Everything below this line is private and must never reach the snapshot.
  phone: '+919876543210',
  email: 'rahul@example.com',
  address: '12 MG Road, Bengaluru',
  notes: 'Chases invoices. Pays late. Do not offer more credit.',
  avatarColor: '#4F46E5',
  currentBalance: balance,
  totalCharged: charged,
  totalPaid: paid,
  transactionCount: 3,
  isFavorite: true,
  status: ClientStatus.active,
  lastTransactionId: 'tx3',
  lastTransaction: null,
  shareId: 'abcdefghijklmnopqrstuvwx',
  createdAt: null,
  updatedAt: null,
  lastActivityAt: null,
);

AppTransaction tx({
  required String id,
  required TxType type,
  required int amount,
  required int delta,
  required int runningBalance,
  String note = '',
  String? projectId,
  bool isReversed = false,
}) => AppTransaction(
  id: id,
  userId: 'uid-1',
  clientId: 'c1',
  projectId: projectId,
  type: type,
  amount: amount,
  delta: delta,
  runningBalance: runningBalance,
  note: note,
  paymentMethod: 'UPI',
  prevTransactionId: null,
  reversesId: null,
  reversedById: null,
  isReversed: isReversed,
  createdAt: DateTime(2026, 8, 18, 13, 30),
  createdBy: 'uid-1',
  createdByName: 'You',
  editedAt: null,
);

Project project(String id, String name) => Project(
  id: id,
  name: name,
  note: '',
  color: '#4F46E5',
  status: ProjectStatus.active,
  createdAt: null,
  updatedAt: null,
);

void main() {
  final website = project('p1', 'Website redesign');
  final retainer = project('p2', 'Monthly retainer');

  final history = [
    tx(
      id: 'tx3',
      type: TxType.payment,
      amount: 500000,
      delta: -500000,
      runningBalance: 1700000,
      note: 'UPI payment',
      projectId: 'p1',
    ),
    tx(
      id: 'tx2',
      type: TxType.charge,
      amount: 200000,
      delta: 200000,
      runningBalance: 2200000,
      note: 'Extra design work',
      projectId: 'p1',
    ),
    tx(
      id: 'tx1',
      type: TxType.opening,
      amount: 2000000,
      delta: 2000000,
      runningBalance: 2000000,
      note: 'Opening balance',
    ),
  ];

  Map<String, dynamic> snapshot() => PortalService.buildSnapshot(
    uid: 'uid-1',
    client: client(),
    transactions: history,
    projects: [website, retainer],
    currencyCode: 'INR',
    updatedAt: 'SERVER_TIME',
  );

  group('what the client can see', () {
    test('carries the figures they need', () {
      final snap = snapshot();
      expect(snap['clientName'], 'Rahul Sharma');
      expect(snap['companyName'], 'ABC Agency');
      expect(snap['currentBalance'], 1700000);
      expect(snap['totalCharged'], 2200000);
      expect(snap['totalPaid'], 500000);
      expect(snap['currency'], 'INR');
    });

    test('includes the full transaction history', () {
      final txs = snapshot()['transactions'] as List;
      expect(txs, hasLength(3));
      expect(txs.first['note'], 'UPI payment');
      expect(txs.first['delta'], -500000);
      expect(txs.first['runningBalance'], 1700000);
      expect(txs.last['type'], 'opening');
    });
  });

  group('what the client must NOT see', () {
    test('no phone, email, address or private notes', () {
      final encoded = snapshot().toString();

      expect(encoded, isNot(contains('9876543210')));
      expect(encoded, isNot(contains('rahul@example.com')));
      expect(encoded, isNot(contains('MG Road')));
      expect(encoded, isNot(contains('Pays late')));
      expect(encoded, isNot(contains('Do not offer more credit')));
    });

    test('the payload is an explicit allow-list of keys', () {
      // A new field added to Client must not silently reach the public page:
      // this fails the moment the snapshot grows a key nobody vetted.
      expect(
        snapshot().keys.toSet(),
        {
          'userId',
          'clientId',
          'clientName',
          'companyName',
          'currency',
          'currentBalance',
          'totalCharged',
          'totalPaid',
          'transactionCount',
          'projects',
          'transactions',
          'historyTruncated',
          'updatedAt',
        },
      );
    });

    test('each history entry is an allow-list too', () {
      final first = (snapshot()['transactions'] as List).first
          as Map<String, dynamic>;
      expect(
        first.keys.toSet(),
        {
          'type',
          'amount',
          'delta',
          'runningBalance',
          'note',
          'paymentMethod',
          'projectName',
          'isReversed',
          'createdAt',
        },
      );
      // The internal chain and audit ids stay private.
      expect(first.containsKey('prevTransactionId'), isFalse);
      expect(first.containsKey('createdBy'), isFalse);
      expect(first.containsKey('projectId'), isFalse);
    });
  });

  group('per-project breakdown', () {
    test('splits pending amounts by tag, computed not stored', () {
      final rows = projectBreakdown(history, [website, retainer]);
      final byName = {for (final r in rows) r['name'] as String: r};

      // Website: +2,000 charged, -5,000 paid  =>  -3,000 net
      expect(byName['Website redesign']!['charged'], 200000);
      expect(byName['Website redesign']!['paid'], 500000);
      expect(byName['Website redesign']!['pending'], -300000);
      expect(byName['Website redesign']!['entries'], 2);

      // Untagged opening balance rolls up under General.
      expect(byName['General']!['pending'], 2000000);
      expect(byName['General']!['entries'], 1);
    });

    test('project totals reconcile to the client balance', () {
      final rows = projectBreakdown(history, [website, retainer]);
      final sum = rows.fold<int>(0, (a, r) => a + (r['pending'] as int));
      expect(sum, client().currentBalance);
    });

    test('a project with no transactions is omitted', () {
      final rows = projectBreakdown(history, [website, retainer]);
      expect(rows.any((r) => r['name'] == 'Monthly retainer'), isFalse);
    });

    test('a tag pointing at a deleted project falls back to General', () {
      final orphaned = [
        tx(
          id: 'x',
          type: TxType.charge,
          amount: 100000,
          delta: 100000,
          runningBalance: 100000,
          projectId: 'deleted-project',
        ),
      ];
      final rows = projectBreakdown(orphaned, const []);
      expect(rows.single['name'], 'General');
      expect(rows.single['id'], isNull);
    });

    test('sorts the largest pending amount first', () {
      final rows = projectBreakdown(history, [website, retainer]);
      for (var i = 1; i < rows.length; i++) {
        expect(
          (rows[i - 1]['pending'] as int) >= (rows[i]['pending'] as int),
          isTrue,
        );
      }
    });
  });

  group('share ids', () {
    test('are long, random and drop look-alike characters', () {
      final ids = List.generate(200, (_) => PortalService.generateShareId());

      for (final id in ids) {
        expect(id, hasLength(24));
        expect(RegExp(r'^[a-zA-Z2-9]+$').hasMatch(id), isTrue);
        // 0/O and 1/l/I are excluded so an id can be read aloud safely.
        expect(id, isNot(contains('0')));
        expect(id, isNot(contains('1')));
        expect(id, isNot(contains('l')));
        expect(id, isNot(contains('I')));
        expect(id, isNot(contains('O')));
      }

      // A repeat inside 200 draws would mean the generator is not random.
      expect(ids.toSet(), hasLength(200));
    });
  });
}
