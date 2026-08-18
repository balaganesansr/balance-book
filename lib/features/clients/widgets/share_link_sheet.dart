import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/contact_links.dart';
import '../../../core/widgets/feedback.dart';
import '../../../models/client.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/client_providers.dart';
import '../../../core/utils/safe_insets.dart';

/// Opens the "share balance link" sheet for [client].
Future<void> showShareLinkSheet(BuildContext context, Client client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ShareLinkSheet(client: client),
  );
}

/// Issues, shows and revokes a client's read-only balance link.
///
/// The wording here matters as much as the code: the user is about to put a
/// client's balance behind a URL, so the sheet states plainly what is exposed,
/// what is not, and that anyone holding the link can read it.
class ShareLinkSheet extends ConsumerStatefulWidget {
  const ShareLinkSheet({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<ShareLinkSheet> {
  bool _busy = false;

  /// Re-read from the provider so the sheet updates the moment the id is
  /// written, without needing the caller to reopen it.
  Client get _client =>
      ref.watch(clientByIdProvider(widget.client.id)) ?? widget.client;

  String get _baseUrl =>
      ref.watch(userProfileProvider).value?.portalBaseUrl.trim() ?? '';

  String? get _link {
    final client = _client;
    if (!client.isShared) return null;
    if (_baseUrl.isEmpty) return null;
    return '$_baseUrl/ledger.html?id=${client.shareId}';
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(portalServiceProvider)
          .enable(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            currencyCode: ref.read(currencyProvider).code,
          );
      if (mounted) AppToast.success(context, 'Balance link created');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final shareId = _client.shareId;
    if (shareId == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke this link?',
      message:
          'The page stops working immediately for anyone who has the link, '
          'including ${widget.client.name}.',
      confirmLabel: 'Revoke link',
      destructive: true,
      detail: const Text(
        'Creating a link again later produces a different address, and the old '
        'one stays dead.',
      ),
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(portalServiceProvider)
          .revoke(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            shareId: shareId,
          );
      if (mounted) AppToast.success(context, 'Link revoked');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(portalServiceProvider)
          .sync(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            currencyCode: ref.read(currencyProvider).code,
          );
      if (mounted) AppToast.success(context, 'Page updated');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) AppToast.success(context, 'Link copied');
  }

  Future<void> _share() async {
    final link = _link;
    if (link == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: _message(link),
        subject: 'Balance for ${widget.client.name}',
      ),
    );
  }

  Future<void> _whatsApp() async {
    final link = _link;
    if (link == null) return;
    try {
      await launchUrl(
        ContactLinks.whatsAppUri(_client.phone, _message(link)),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) AppToast.info(context, 'Could not open WhatsApp.');
    }
  }

  String _message(String link) =>
      'Hi ${MessageTemplates.firstName(widget.client.name)}, you can check your '
      'current balance and payment history any time here:\n$link';

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final link = _link;
    final colors = context.colors;
    final needsBaseUrl = client.isShared && _baseUrl.isEmpty;

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
                      color: context.scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      color: context.scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balance link', style: context.text.titleLarge),
                        const SizedBox(height: 2),
                        Text(client.name, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (!client.isShared) ...[
                const _WhatTheySee(),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _enable,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_link_rounded, size: 20),
                    label: Text(_busy ? 'Creating…' : 'Create balance link'),
                  ),
                ),
              ] else ...[
                if (needsBaseUrl)
                  _Notice(
                    tint: colors.charge,
                    icon: Icons.settings_outlined,
                    text:
                        'A link exists but there is nowhere to point it yet. '
                        'Set where ledger.html is hosted under '
                        'Settings → Balance link, then come back.',
                  )
                else
                  _LinkBox(link: link!, onCopy: _copy),

                const SizedBox(height: 14),
                _Notice(
                  tint: context.scheme.onSurfaceVariant,
                  icon: Icons.lock_outline_rounded,
                  text:
                      'Anyone with this link can see this balance, so treat it '
                      'like a password. It shows no phone number, email, '
                      'address or your private notes.',
                ),

                if (link != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (ContactLinks.isCallable(client.phone)) ...[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _busy ? null : _whatsApp,
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('Send'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Update page'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.scheme.error,
                        ),
                        onPressed: _busy ? null : _revoke,
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        label: const Text('Revoke'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'The page refreshes itself whenever you record a charge or '
                  'payment. "Update page" is only needed if something looks '
                  'stale.',
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatTheySee extends StatelessWidget {
  const _WhatTheySee();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creates a private web page showing:',
            style: context.text.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _Bullet(yes: true, text: 'Their current balance and status'),
          const _Bullet(yes: true, text: 'What is pending per project'),
          const _Bullet(yes: true, text: 'Their charge and payment history'),
          const SizedBox(height: 8),
          const _Bullet(yes: false, text: 'Phone, email or address'),
          const _Bullet(yes: false, text: 'Your private notes about them'),
          const _Bullet(yes: false, text: 'Any of your other clients'),
          const SizedBox(height: 10),
          Text(
            'The address contains a 24-character random key, so it cannot be '
            'guessed. You can revoke it at any time.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.yes, required this.text});

  final bool yes;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tint = yes ? context.colors.payment : context.scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            yes ? Icons.check_rounded : Icons.close_rounded,
            size: 15,
            color: tint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: yes ? context.scheme.onSurface : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkBox extends StatelessWidget {
  const _LinkBox({required this.link, required this.onCopy});

  final String link;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link,
                style: context.text.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: context.scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.copy_rounded,
              size: 16,
              color: context.scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.tint,
    required this.icon,
    required this.text,
  });

  final Color tint;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}
