import 'package:balance_book/core/utils/money.dart';
import 'package:balance_book/models/app_transaction.dart';
import 'package:balance_book/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the arithmetic that `TransactionService` performs inside its
/// Firestore transaction, so the rules can be verified without a network.
({int balance, List<int> running}) replay(
  int opening,
  List<TxDraft> drafts,
) {
  var balance = opening;
  final running = <int>[];
  for (final draft in drafts) {
    balance += draft.delta;
    running.add(balance);
  }
  return (balance: balance, running: running);
}

void main() {
  group('TxDraft.delta, the single place the sign of money is decided', () {
    test('a charge increases the balance', () {
      expect(
        const TxDraft(type: TxType.charge, amount: 200000).delta,
        200000,
      );
    });

    test('a payment decreases the balance', () {
      expect(
        const TxDraft(type: TxType.payment, amount: 500000).delta,
        -500000,
      );
    });

    test('an opening balance increases it', () {
      expect(
        const TxDraft(type: TxType.opening, amount: 2000000).delta,
        2000000,
      );
    });

    test('an adjustment follows its direction', () {
      expect(
        const TxDraft(
          type: TxType.adjustment,
          amount: 100000,
          increase: true,
        ).delta,
        100000,
      );
      expect(
        const TxDraft(
          type: TxType.adjustment,
          amount: 100000,
          increase: false,
        ).delta,
        -100000,
      );
    });

    test('a reversal cannot be built from a draft', () {
      expect(
        () => const TxDraft(type: TxType.reversal, amount: 1).delta,
        throwsStateError,
      );
    });
  });

  group('the worked example from the brief', () {
    // Opening ₹20,000 → charge ₹2,000 → payment ₹5,000 → ₹17,000
    const opening = 20000 * 100;

    test('balance walks 20,000 → 22,000 → 17,000', () {
      final result = replay(opening, const [
        TxDraft(type: TxType.charge, amount: 2000 * 100),
        TxDraft(type: TxType.payment, amount: 5000 * 100),
      ]);

      expect(result.running, [22000 * 100, 17000 * 100]);
      expect(result.balance, 17000 * 100);
      expect(Money.format(result.balance), '₹17,000');
    });

    test('each running balance equals the sum of everything before it', () {
      final drafts = const [
        TxDraft(type: TxType.opening, amount: 20000 * 100),
        TxDraft(type: TxType.charge, amount: 2000 * 100),
        TxDraft(type: TxType.payment, amount: 5000 * 100),
        TxDraft(type: TxType.charge, amount: 10000 * 100),
      ];
      final result = replay(0, drafts);

      var sum = 0;
      for (var i = 0; i < drafts.length; i++) {
        sum += drafts[i].delta;
        expect(
          result.running[i],
          sum,
          reason: 'running balance at index $i must equal the running sum',
        );
      }
    });
  });

  group('reversal arithmetic', () {
    test('reversing a charge returns the balance to where it was', () {
      const before = 20000 * 100;
      const charge = TxDraft(type: TxType.charge, amount: 2000 * 100);

      final after = before + charge.delta;
      expect(after, 22000 * 100);

      // A reversal's delta is the negation of the original's.
      final reversed = after + (-charge.delta);
      expect(reversed, before);
    });

    test('reversing a payment restores the debt', () {
      const before = 22000 * 100;
      const payment = TxDraft(type: TxType.payment, amount: 5000 * 100);

      final after = before + payment.delta;
      expect(after, 17000 * 100);
      expect(after + (-payment.delta), before);
    });
  });

  group('balance states', () {
    test('positive is outstanding, zero is settled, negative is credit', () {
      expect(BalanceStateX.of(1700000), BalanceState.outstanding);
      expect(BalanceStateX.of(0), BalanceState.settled);
      expect(BalanceStateX.of(-200000), BalanceState.credit);
    });

    test('a payment larger than the balance leaves a credit', () {
      const balance = 2000 * 100;
      const payment = TxDraft(type: TxType.payment, amount: 5000 * 100);
      final after = balance + payment.delta;

      expect(after, -3000 * 100);
      expect(BalanceStateX.of(after), BalanceState.credit);
      expect(Money.format(after, absolute: true), '₹3,000');
    });
  });

  group('type identifiers survive a round trip', () {
    test('every type maps to and from its stored id', () {
      for (final type in TxType.values) {
        expect(TxTypeX.fromId(type.id), type);
      }
    });

    test('an unknown id falls back to charge rather than throwing', () {
      expect(TxTypeX.fromId('nonsense'), TxType.charge);
      expect(TxTypeX.fromId(null), TxType.charge);
    });

    test('client and project statuses round trip too', () {
      for (final status in ClientStatus.values) {
        expect(ClientStatusX.fromId(status.id), status);
      }
      for (final status in ProjectStatus.values) {
        expect(ProjectStatusX.fromId(status.id), status);
      }
      expect(ClientStatusX.fromId('nonsense'), ClientStatus.active);
    });
  });
}
