import 'money.dart';

/// Builds the `tel:` / WhatsApp links and the message text used by the Call,
/// WhatsApp and Remind actions.
///
/// The app never places a call or sends a message itself. It hands a URL to
/// the OS and lets the user's own dialler or WhatsApp take over. Nothing is
/// ever sent automatically.
class ContactLinks {
  const ContactLinks._();

  /// Dial code assumed when a number is stored without one. Indian mobile
  /// numbers are 10 digits, which is the common case for this app's audience.
  static const defaultDialCode = '91';

  static String digitsOnly(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static bool isCallable(String phone) => digitsOnly(phone).length >= 6;

  /// `tel:` URI for the device dialler.
  static Uri telUri(String phone) {
    final trimmed = phone.trim();
    // Keep a leading + so international numbers dial correctly.
    final normalised = trimmed.startsWith('+')
        ? '+${digitsOnly(trimmed)}'
        : digitsOnly(trimmed);
    return Uri.parse('tel:$normalised');
  }

  /// WhatsApp needs a full international number with no `+` or separators.
  static String whatsAppNumber(String phone, {String? dialCode}) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return digitsOnly(trimmed);

    final digits = digitsOnly(trimmed);
    if (digits.length == 10) return '${dialCode ?? defaultDialCode}$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '${dialCode ?? defaultDialCode}${digits.substring(1)}';
    }
    return digits;
  }

  /// `https://wa.me/<number>?text=<message>`. Opens WhatsApp with the message
  /// pre-filled and waiting for the user to press send.
  static Uri whatsAppUri(String phone, String message, {String? dialCode}) {
    return Uri.https(
      'wa.me',
      '/${whatsAppNumber(phone, dialCode: dialCode)}',
      {'text': message},
    );
  }

  static Uri emailUri(String email, {String? subject, String? body}) {
    return Uri(
      scheme: 'mailto',
      path: email.trim(),
      query: Uri(
        queryParameters: {
          'subject': ?subject,
          'body': ?body,
        },
      ).query,
    );
  }
}

/// The message templates used for reminders and balance updates.
///
/// Kept in one place so the tone stays consistent, and so a user editing the
/// text before sending always starts from something polite and complete.
class MessageTemplates {
  const MessageTemplates._();

  static String firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Polite nudge for an outstanding balance.
  static String reminder({
    required String clientName,
    required int balance,
    required Currency currency,
    String paymentDetails = '',
  }) {
    final amount = Money.format(balance.abs(), currency: currency);
    final buffer = StringBuffer()
      ..write('Hi ${firstName(clientName)}, ')
      ..write(
        'just a quick reminder that $amount is currently pending on your '
        'account. Please let me know when you expect to make the payment.',
      );

    if (paymentDetails.trim().isNotEmpty) {
      buffer.write('\n\nPayment details:\n${paymentDetails.trim()}');
    }
    buffer.write('\n\nThank you!');
    return buffer.toString();
  }

  /// Neutral balance update. Works for any balance state.
  static String balanceUpdate({
    required String clientName,
    required int balance,
    required Currency currency,
    String paymentDetails = '',
  }) {
    final name = firstName(clientName);
    if (balance == 0) {
      return 'Hi $name, your account is fully settled. There is nothing '
          'pending at the moment. Thank you!';
    }
    if (balance < 0) {
      final amount = Money.format(-balance, currency: currency);
      return 'Hi $name, your account currently shows a credit of $amount. '
          'This will be adjusted against your next invoice.';
    }

    final amount = Money.format(balance, currency: currency);
    final buffer = StringBuffer()
      ..write(
        'Hi $name, your current outstanding balance is $amount. '
        'Please let me know if you need the payment details.',
      );
    if (paymentDetails.trim().isNotEmpty) {
      buffer.write('\n\nPayment details:\n${paymentDetails.trim()}');
    }
    return buffer.toString();
  }

  /// Confirmation sent after recording a payment.
  static String paymentReceived({
    required String clientName,
    required int amount,
    required int balanceAfter,
    required Currency currency,
  }) {
    final received = Money.format(amount, currency: currency);
    final name = firstName(clientName);
    if (balanceAfter <= 0) {
      return 'Hi $name, I have received $received, and your account is now fully '
          'settled. Thank you!';
    }
    final pending = Money.format(balanceAfter, currency: currency);
    return 'Hi $name, I have received $received. Thank you! '
        'The remaining balance on your account is $pending.';
  }
}
