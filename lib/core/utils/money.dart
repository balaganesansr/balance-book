import 'package:intl/intl.dart';

/// A currency the app can display amounts in.
///
/// Amounts are always stored as integer *minor units* (paise for INR, cents for
/// USD, ...). Changing the display currency never rewrites stored amounts. It
/// only changes how the same integers are rendered.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.name,
    this.decimalDigits = 2,
  });

  final String code;
  final String symbol;

  /// Locale used for digit grouping. `en_IN` gives the Indian 2-2-3 grouping
  /// (₹12,50,000) rather than the western 3-3-3 grouping (₹1,250,000).
  final String locale;
  final String name;
  final int decimalDigits;

  int get minorPerMajor => decimalDigits == 0 ? 1 : 100;

  static const inr = Currency(
    code: 'INR',
    symbol: '₹',
    locale: 'en_IN',
    name: 'Indian Rupee',
  );
  static const usd = Currency(
    code: 'USD',
    symbol: r'$',
    locale: 'en_US',
    name: 'US Dollar',
  );
  static const eur = Currency(
    code: 'EUR',
    symbol: '€',
    locale: 'de_DE',
    name: 'Euro',
  );
  static const gbp = Currency(
    code: 'GBP',
    symbol: '£',
    locale: 'en_GB',
    name: 'British Pound',
  );
  static const aed = Currency(
    code: 'AED',
    symbol: 'AED ',
    locale: 'en_US',
    name: 'UAE Dirham',
  );

  static const supported = <Currency>[inr, usd, eur, gbp, aed];

  static Currency fromCode(String? code) => supported.firstWhere(
    (c) => c.code == code,
    orElse: () => inr,
  );
}

/// Formatting and parsing for integer minor-unit amounts.
///
/// Every monetary value in the app passes through here. Nothing else should
/// divide by 100 or build a currency string by hand.
class Money {
  const Money._();

  /// Splits a minor amount into (major, minor-remainder), both non-negative.
  /// The sign is returned separately so the caller controls how it is rendered.
  static ({int sign, int major, int minor}) _parts(
    int amount,
    Currency currency,
  ) {
    final sign = amount.isNegative ? -1 : 1;
    final abs = amount.abs();
    final per = currency.minorPerMajor;
    return (sign: sign, major: abs ~/ per, minor: abs % per);
  }

  /// Formats an integer minor amount for display.
  ///
  /// ```dart
  /// Money.format(200000);              // ₹2,000
  /// Money.format(12500000);            // ₹12,50,000
  /// Money.format(-200000, signed: true); // -₹2,000
  /// ```
  ///
  /// Decimals are hidden when the amount is whole, which keeps balances easy to
  /// scan; pass [alwaysShowDecimals] for statement-style output such as CSV.
  static String format(
    int amount, {
    Currency currency = Currency.inr,
    bool withSymbol = true,
    bool signed = false,
    bool absolute = false,
    bool alwaysShowDecimals = false,
  }) {
    final p = _parts(amount, currency);
    final grouped = NumberFormat.decimalPattern(currency.locale).format(p.major);

    final buffer = StringBuffer();
    if (!absolute) {
      if (p.sign < 0) {
        buffer.write('-');
      } else if (signed && amount != 0) {
        buffer.write('+');
      }
    }
    if (withSymbol) buffer.write(currency.symbol);
    buffer.write(grouped);

    if (currency.decimalDigits > 0 && (alwaysShowDecimals || p.minor != 0)) {
      buffer.write('.');
      buffer.write(p.minor.toString().padLeft(currency.decimalDigits, '0'));
    }
    return buffer.toString();
  }

  /// Plain digits with no symbol, for CSV and text fields.
  static String formatPlain(int amount, {Currency currency = Currency.inr}) =>
      format(
        amount,
        currency: currency,
        withSymbol: false,
        alwaysShowDecimals: true,
      );

  /// The value to seed an amount text field with, e.g. `2000` or `2000.50`.
  static String toInput(int amount, {Currency currency = Currency.inr}) {
    final p = _parts(amount, currency);
    if (currency.decimalDigits == 0 || p.minor == 0) return p.major.toString();
    return '${p.major}.${p.minor.toString().padLeft(currency.decimalDigits, '0')}';
  }

  /// Parses user input into integer minor units.
  ///
  /// Accepts grouped input (`1,25,000`), a leading symbol, and up to
  /// [Currency.decimalDigits] decimals. Returns `null` when the text is not a
  /// valid amount, so callers can show a field error rather than guess.
  static int? tryParse(String input, {Currency currency = Currency.inr}) {
    var text = input.trim();
    if (text.isEmpty) return null;

    // Strip the currency symbol, grouping separators and whitespace.
    text = text
        .replaceAll(currency.symbol.trim(), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .trim();
    if (text.isEmpty) return null;

    final negative = text.startsWith('-');
    if (negative || text.startsWith('+')) text = text.substring(1);

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return null;
    if (text == '.' || text.isEmpty) return null;

    final dot = text.indexOf('.');
    final majorText = dot == -1 ? text : text.substring(0, dot);
    var minorText = dot == -1 ? '' : text.substring(dot + 1);

    if (minorText.length > currency.decimalDigits) return null;
    if (currency.decimalDigits == 0 && minorText.isNotEmpty) return null;

    minorText = minorText.padRight(currency.decimalDigits, '0');

    final major = majorText.isEmpty ? 0 : int.tryParse(majorText);
    final minor = minorText.isEmpty ? 0 : int.tryParse(minorText);
    if (major == null || minor == null) return null;

    // Guard against absurd input overflowing later arithmetic.
    if (major > 9007199254740) return null;

    final total = major * currency.minorPerMajor + minor;
    return negative ? -total : total;
  }
}
