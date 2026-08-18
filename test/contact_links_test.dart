import 'package:balance_book/core/utils/contact_links.dart';
import 'package:balance_book/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('telUri', () {
    test('strips separators but keeps a leading +', () {
      expect(ContactLinks.telUri('+91 98765 43210').toString(), 'tel:+919876543210');
      expect(ContactLinks.telUri('98765-43210').toString(), 'tel:9876543210');
      expect(ContactLinks.telUri('(022) 1234 5678').toString(), 'tel:02212345678');
    });
  });

  group('whatsAppNumber', () {
    test('adds the default dial code to a bare 10-digit number', () {
      expect(ContactLinks.whatsAppNumber('9876543210'), '919876543210');
      expect(ContactLinks.whatsAppNumber('98765 43210'), '919876543210');
    });

    test('leaves an already-international number alone', () {
      expect(ContactLinks.whatsAppNumber('+919876543210'), '919876543210');
      expect(ContactLinks.whatsAppNumber('+1 415 555 2671'), '14155552671');
    });

    test('drops a national trunk zero', () {
      expect(ContactLinks.whatsAppNumber('09876543210'), '919876543210');
    });

    test('honours an explicit dial code', () {
      expect(
        ContactLinks.whatsAppNumber('4155552671', dialCode: '1'),
        '14155552671',
      );
    });
  });

  group('whatsAppUri', () {
    test('builds a wa.me link with the message as a query parameter', () {
      final uri = ContactLinks.whatsAppUri('9876543210', 'Hi Rahul');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Hi Rahul');
    });

    test('escapes a message containing symbols and newlines', () {
      final uri = ContactLinks.whatsAppUri(
        '9876543210',
        'Balance ₹17,000\nThanks & regards',
      );
      // Round-trips intact rather than being truncated at the & or newline.
      expect(
        uri.queryParameters['text'],
        'Balance ₹17,000\nThanks & regards',
      );
    });
  });

  group('isCallable', () {
    test('needs enough digits to be a real number', () {
      expect(ContactLinks.isCallable('9876543210'), isTrue);
      expect(ContactLinks.isCallable('+91 98765 43210'), isTrue);
      expect(ContactLinks.isCallable(''), isFalse);
      expect(ContactLinks.isCallable('12345'), isFalse);
      expect(ContactLinks.isCallable('not a number'), isFalse);
    });
  });

  group('reminder messages', () {
    test('names the client and the amount owed', () {
      final message = MessageTemplates.reminder(
        clientName: 'Rahul Sharma',
        balance: 17000 * 100,
        currency: Currency.inr,
      );
      expect(message, contains('Hi Rahul,'));
      expect(message, contains('₹17,000'));
      expect(message, contains('pending'));
    });

    test('appends payment details when they exist', () {
      final message = MessageTemplates.reminder(
        clientName: 'Rahul',
        balance: 100000,
        currency: Currency.inr,
        paymentDetails: 'UPI: rahul@bank',
      );
      expect(message, contains('UPI: rahul@bank'));
    });

    test('balance updates read correctly in all three states', () {
      String update(int balance) => MessageTemplates.balanceUpdate(
        clientName: 'Rahul Sharma',
        balance: balance,
        currency: Currency.inr,
      );

      expect(update(17000 * 100), contains('outstanding balance is ₹17,000'));
      expect(update(0), contains('fully settled'));
      expect(update(-2000 * 100), contains('credit of ₹2,000'));
    });

    test('payment confirmations say whether anything is left', () {
      final settled = MessageTemplates.paymentReceived(
        clientName: 'Rahul',
        amount: 5000 * 100,
        balanceAfter: 0,
        currency: Currency.inr,
      );
      expect(settled, contains('fully settled'));

      final partial = MessageTemplates.paymentReceived(
        clientName: 'Rahul',
        amount: 5000 * 100,
        balanceAfter: 17000 * 100,
        currency: Currency.inr,
      );
      expect(partial, contains('₹5,000'));
      expect(partial, contains('₹17,000'));
    });

    test('falls back gracefully when the name is missing', () {
      expect(MessageTemplates.firstName(''), 'there');
      expect(MessageTemplates.firstName('   '), 'there');
      expect(MessageTemplates.firstName('Rahul Sharma'), 'Rahul');
    });
  });
}
