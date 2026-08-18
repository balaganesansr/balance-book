import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/contact_links.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/money_text.dart';
import '../../../models/client.dart';
import '../../../providers/auth_providers.dart';
import '../../../core/utils/safe_insets.dart';

/// Opens the reminder composer for [client].
Future<void> showReminderSheet(BuildContext context, Client client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReminderSheet(client: client),
  );
}

/// Composes a payment reminder and hands it to WhatsApp, the dialler, the
/// clipboard or the share sheet.
///
/// Nothing is ever sent automatically. The message is fully editable first, and
/// every action opens the user's own app with the text pre-filled so they press
/// send themselves.
class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet> {
  late final TextEditingController _message;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _message = TextEditingController();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final profile = ref.read(userProfileProvider).value;
    final currency = ref.read(currencyProvider);
    final balance = widget.client.currentBalance;

    _message.text = balance > 0
        ? MessageTemplates.reminder(
            clientName: widget.client.name,
            balance: balance,
            currency: currency,
            paymentDetails: profile?.paymentDetails ?? '',
          )
        : MessageTemplates.balanceUpdate(
            clientName: widget.client.name,
            balance: balance,
            currency: currency,
            paymentDetails: profile?.paymentDetails ?? '',
          );
  }

  Future<void> _openUri(Uri uri, String failureMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) AppToast.info(context, failureMessage);
    } catch (_) {
      if (mounted) AppToast.info(context, failureMessage);
    }
  }

  Future<void> _whatsApp() async {
    final uri = ContactLinks.whatsAppUri(widget.client.phone, _message.text);
    await _openUri(
      uri,
      'Could not open WhatsApp. Copy the message and send it manually.',
    );
  }

  Future<void> _call() async {
    await _openUri(
      ContactLinks.telUri(widget.client.phone),
      'No dialler app available on this device.',
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _message.text));
    if (mounted) AppToast.success(context, 'Reminder copied');
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: _message.text,
        subject: 'Payment reminder for ${widget.client.name}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _seed();
    final client = widget.client;
    final canContact = ContactLinks.isCallable(client.phone);
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, context.sheetBottomPadding()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.charge.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: colors.charge,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Send a reminder', style: context.text.titleLarge),
                        const SizedBox(height: 2),
                        Text(client.name, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('Current balance', style: context.text.bodySmall),
                    const Spacer(),
                    MoneyText(
                      client.currentBalance,
                      absolute: true,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BalanceStatusChip(
                      balance: client.currentBalance,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Message',
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                maxLines: 7,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write your reminder…',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Edit this freely before sending. Nothing is sent for you.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 20),

              if (canContact) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _whatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('Open in WhatsApp'),
                  ),
                ),
                const SizedBox(height: 10),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Add a phone number to this client to send reminders by '
                    'WhatsApp or to call them.',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.charge,
                    ),
                  ),
                ),

              Row(
                children: [
                  if (canContact) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
