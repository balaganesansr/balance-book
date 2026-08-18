import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/contact_links.dart';
import '../../../core/widgets/client_avatar.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/money_text.dart';
import '../../../models/client.dart';
import '../../../models/enums.dart';

/// A client row in the list.
///
/// The balance is the loudest thing on the row, because that is the question
/// this app exists to answer. Everything else (company, last activity, the
/// call button) sits around it without competing.
class ClientCard extends StatelessWidget {
  const ClientCard({
    super.key,
    required this.client,
    required this.onTap,
    this.showCallButton = true,
  });

  final Client client;
  final VoidCallback onTap;
  final bool showCallButton;

  Future<void> _call(BuildContext context) async {
    final uri = ContactLinks.telUri(client.phone);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.info(context, 'No dialler app available on this device.');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.info(context, 'Could not open the dialler.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canCall = showCallButton && ContactLinks.isCallable(client.phone);

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClientAvatar.of(client, showFavorite: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            client.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (client.isArchived) ...[
                          const SizedBox(width: 6),
                          _MiniTag(
                            label: 'Archived',
                            tint: context.scheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    if (client.displayCompany.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        client.displayCompany,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 5),
                    _SubLine(client: client),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BalanceCell(balance: client.currentBalance),
              if (canCall) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _call(context),
                  tooltip: 'Call ${client.name}',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.phone_rounded,
                    size: 19,
                    color: context.scheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone number, or the last thing that happened on the account.
class _SubLine extends StatelessWidget {
  const _SubLine({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final last = client.lastTransaction;
    final at = client.lastActivityAt;

    final String text;
    final IconData icon;

    if (last != null && at != null) {
      final label = last.note.trim().isNotEmpty
          ? last.note.trim()
          : last.type.label;
      text = '$label · ${AppDate.relative(at)}';
      icon = last.delta >= 0
          ? Icons.north_east_rounded
          : Icons.south_west_rounded;
    } else if (client.phone.trim().isNotEmpty) {
      text = client.phone.trim();
      icon = Icons.phone_outlined;
    } else {
      text = 'No transactions yet';
      icon = Icons.schedule_rounded;
    }

    return Row(
      children: [
        Icon(icon, size: 12, color: context.scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Compact variant used on the dashboard's "top outstanding" list.
class ClientMiniCard extends StatelessWidget {
  const ClientMiniCard({
    super.key,
    required this.client,
    required this.onTap,
  });

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              ClientAvatar.of(client, size: 36, showFavorite: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    if (client.displayCompany.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        client.displayCompany,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(
                client.currentBalance,
                absolute: true,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                color: context.colors.forState(client.balanceState),
                semanticsPrefix: '${client.name} balance',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
