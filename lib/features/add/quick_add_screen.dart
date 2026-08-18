import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/client_avatar.dart';
import '../../core/widgets/money_text.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../providers/client_providers.dart';
import '../clients/widgets/client_picker.dart';
import '../transactions/transaction_sheet.dart';

/// The centre tab: the three things people open the app to do.
///
/// The whole point is to shorten "open app → find client → record it" to a
/// couple of taps, so recent clients are one tap from a charge or a payment.
class QuickAddScreen extends ConsumerWidget {
  const QuickAddScreen({super.key});

  Future<void> _pickThen(
    BuildContext context,
    TxType type,
  ) async {
    final client = await showClientPicker(
      context,
      title: type == TxType.payment
          ? 'Record payment from…'
          : 'Add charge for…',
    );
    if (client == null || !context.mounted) return;
    await showTransactionSheet(context, client: client, type: type);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final recent = ref.watch(recentClientsProvider);
    final colors = context.colors;
    final hasClients = clients.any((c) => !c.isArchived);

    return Scaffold(
      appBar: AppBar(title: const Text('Add')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _BigAction(
            icon: Icons.add_rounded,
            title: 'Add charge',
            subtitle: 'Extra work, retainer, new invoice',
            tint: colors.charge,
            enabled: hasClients,
            onTap: () => _pickThen(context, TxType.charge),
          ),
          const SizedBox(height: 12),
          _BigAction(
            icon: Icons.south_west_rounded,
            title: 'Record payment',
            subtitle: 'Money received from a client',
            tint: colors.payment,
            enabled: hasClients,
            onTap: () => _pickThen(context, TxType.payment),
          ),
          const SizedBox(height: 12),
          _BigAction(
            icon: Icons.person_add_alt_1_rounded,
            title: 'New client',
            subtitle: 'With an optional opening balance',
            tint: context.scheme.primary,
            onTap: () => context.push('/clients/new'),
          ),

          if (!hasClients)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Add a client first, because charges and payments always belong to '
                'someone.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),

          if (recent.isNotEmpty) ...[
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Recent clients',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final client in recent.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentRow(client: client),
              ),
          ],
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: tint, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A recent client with charge and payment shortcuts built in.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: [
          ClientAvatar.of(client, size: 36),
          const SizedBox(width: 10),
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
                MoneyText(
                  client.currentBalance,
                  absolute: true,
                  style: context.text.labelSmall,
                  color: colors.forState(client.balanceState),
                  semanticsPrefix: 'Balance',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add charge for ${client.name}',
            onPressed: () => showTransactionSheet(
              context,
              client: client,
              type: TxType.charge,
            ),
            icon: Icon(Icons.add_rounded, color: colors.charge),
          ),
          IconButton(
            tooltip: 'Record payment from ${client.name}',
            onPressed: () => showTransactionSheet(
              context,
              client: client,
              type: TxType.payment,
            ),
            icon: Icon(Icons.south_west_rounded, color: colors.payment),
          ),
        ],
      ),
    );
  }
}
