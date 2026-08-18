import 'package:balance_book/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.format with Indian grouping', () {
    test('formats whole rupee amounts with 2-2-3 grouping', () {
      expect(Money.format(2000 * 100), '₹2,000');
      expect(Money.format(20000 * 100), '₹20,000');
      expect(Money.format(125000 * 100), '₹1,25,000');
      expect(Money.format(1250000 * 100), '₹12,50,000');
      expect(Money.format(142500 * 100), '₹1,42,500');
      expect(Money.format(10000000 * 100), '₹1,00,00,000');
    });

    test('hides paise when the amount is whole, shows them when it is not', () {
      expect(Money.format(200000), '₹2,000');
      expect(Money.format(200050), '₹2,000.50');
      expect(Money.format(200005), '₹2,000.05');
    });

    test('renders zero without a sign', () {
      expect(Money.format(0), '₹0');
      expect(Money.format(0, signed: true), '₹0');
    });

    test('signs negatives, and adds + only when asked', () {
      expect(Money.format(-200000), '-₹2,000');
      expect(Money.format(200000, signed: true), '+₹2,000');
      expect(Money.format(-200000, signed: true), '-₹2,000');
    });

    test('absolute drops the sign entirely', () {
      expect(Money.format(-1700000, absolute: true), '₹17,000');
      expect(Money.format(-1700000, absolute: true, signed: true), '₹17,000');
    });

    test('can omit the symbol', () {
      expect(Money.format(200000, withSymbol: false), '2,000');
    });

    test('alwaysShowDecimals pads to the currency scale', () {
      expect(Money.formatPlain(200000), '2,000.00');
      expect(Money.formatPlain(-200050), '-2,000.50');
    });
  });

  group('Money.format with other currencies', () {
    test('uses western grouping outside INR', () {
      expect(Money.format(125000 * 100, currency: Currency.usd), r'$125,000');
      expect(Money.format(1250000 * 100, currency: Currency.gbp), '£1,250,000');
      // Same integer, two groupings, the only difference is the locale.
      expect(Money.format(1250000 * 100, currency: Currency.inr), '₹12,50,000');
    });

    test('falls back to INR for an unknown code', () {
      expect(Currency.fromCode('XYZ'), Currency.inr);
      expect(Currency.fromCode(null), Currency.inr);
      expect(Currency.fromCode('USD'), Currency.usd);
    });
  });

  group('Money.tryParse', () {
    test('parses plain and grouped input into minor units', () {
      expect(Money.tryParse('2000'), 200000);
      expect(Money.tryParse('2,000'), 200000);
      expect(Money.tryParse('1,25,000'), 12500000);
      expect(Money.tryParse(' 2000 '), 200000);
    });

    test('parses decimals up to the currency scale', () {
      expect(Money.tryParse('2000.5'), 200050);
      expect(Money.tryParse('2000.50'), 200050);
      expect(Money.tryParse('0.05'), 5);
      expect(Money.tryParse('.5'), 50);
    });

    test('rejects more precision than the currency has', () {
      expect(Money.tryParse('2000.555'), isNull);
    });

    test('strips a leading currency symbol', () {
      expect(Money.tryParse('₹2,000'), 200000);
    });

    test('handles signs', () {
      expect(Money.tryParse('-2000'), -200000);
      expect(Money.tryParse('+2000'), 200000);
    });

    test('rejects junk rather than guessing', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('2.0.0'), isNull);
      expect(Money.tryParse('.'), isNull);
      expect(Money.tryParse('1e5'), isNull);
    });

    test('rejects absurd magnitudes before they reach arithmetic', () {
      expect(Money.tryParse('99999999999999999999'), isNull);
    });

    test('round-trips through toInput', () {
      for (final amount in [0, 5, 50, 200000, 12500000, 200050]) {
        expect(Money.tryParse(Money.toInput(amount)), amount);
      }
    });
  });

  group('no floating point anywhere', () {
    test('a long chain of parses and sums stays exact', () {
      // 0.1 + 0.2 style drift would show up here if paise were doubles.
      var balance = 0;
      for (var i = 0; i < 1000; i++) {
        balance += Money.tryParse('0.10')!;
      }
      expect(balance, 10000); // exactly ₹100.00
      expect(Money.format(balance), '₹100');
    });
  });
}
