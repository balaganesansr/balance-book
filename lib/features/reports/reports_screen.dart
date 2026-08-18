import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_export.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/client_avatar.dart';
import '../../core/widgets/date_filter.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/client.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../core/utils/safe_insets.dart';

/// A deliberately small reports screen.
///
/// Four numbers that a freelancer actually acts on: what is owed, what came
/// in, what went out, and who sits where, rather than a general-purpose
/// accounting suite.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final totalsAsync = ref.watch(periodTotalsProvider(range));
    final totals = totalsAsync.value ?? PeriodTotals.empty;
    final portfolio = ref.watch(portfolioTotalsProvider);
    final sort = ref.watch(reportSortProvider);
    final clients = ref.watch(clientPerformanceProvider(sort));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export summary',
            onPressed: () => _exportSummary(context, ref, clients),
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: context.scrollBottomPadding(40)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outstanding right now', style: context.text.bodySmall),
                  const SizedBox(height: 8),
                  MoneyText(
                    portfolio.outstanding,
                    style: context.text.headlineLarge,
                    semanticsPrefix: 'Total outstanding',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Across ${portfolio.clientsWithDues} of '
                    '${portfolio.totalClients} clients'
                    '${portfolio.credit > 0 ? ' · ${portfolio.clientsInCredit} in credit' : ''}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          DateFilterBar(
            value: range,
            onChanged: (r) => ref.read(reportRangeProvider.notifier).set(r),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Payments received',
                    icon: Icons.south_west_rounded,
                    tint: colors.payment,
                    caption: range.label,
                    value: MoneyText(
                      totals.paymentsReceived,
                      absolute: true,
                      color: colors.payment,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Charges added',
                    icon: Icons.north_east_rounded,
                    tint: colors.charge,
                    caption: range.label,
                    value: MoneyText(
                      totals.chargesAdded,
                      absolute: true,
                      color: colors.charge,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (totals.truncated)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Only the most recent $periodQueryLimit transactions in this '
                'period were counted, so these two figures may be low. Choose '
                'a narrower range for exact totals.',
                style: context.text.bodySmall?.copyWith(color: colors.charge),
              ),
            ),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(
                    totals.net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                    color: totals.net >= 0 ? colors.charge : colors.payment,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      totals.net >= 0
                          ? 'Net increase in what clients owe you'
                          : 'Net reduction in what clients owe you',
                      style: context.text.bodySmall,
                    ),
                  ),
                  MoneyText(
                    totals.net,
                    absolute: true,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    color: totals.net >= 0 ? colors.charge : colors.payment,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              title: 'Client performance',
              subtitle: 'Lifetime totals per client',
              padding: EdgeInsets.zero,
              action: PopupMenuButton<ClientSort>(
                tooltip: 'Sort',
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                position: PopupMenuPosition.under,
                onSelected: (value) =>
                    ref.read(reportSortProvider.notifier).set(value),
                itemBuilder: (context) => [
                  for (final option in ClientSort.values)
                    PopupMenuItem(value: option, child: Text(option.label)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (clients.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.bar_chart_rounded,
              title: 'No clients yet',
              message: 'Add a client to see how the numbers stack up.',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < clients.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: colors.hairline),
                      _PerformanceRow(client: clients[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportSummary(
    BuildContext context,
    WidgetRef ref,
    List<Client> clients,
  ) async {
    if (clients.isEmpty) {
      AppToast.info(context, 'Nothing to export yet.');
      return;
    }
    try {
      final csv = CsvExport.clientSummary(
        clients: clients,
        currency: ref.read(currencyProvider),
      );
      final file = await CsvExport.writeTempFile(
        csv,
        CsvExport.fileNameFor('clients-summary'),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Client summary',
          text: 'Client balances summary',
        ),
      );
    } catch (error) {
      if (context.mounted) AppToast.error(context, error);
    }
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => context.push('/clients/${client.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                ClientAvatar.of(client, size: 32),
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
                      if (client.displayCompany.isNotEmpty)
                        Text(
                          client.displayCompany,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall,
                        ),
                    ],
                  ),
                ),
                BalanceCell(balance: client.currentBalance),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Charged',
                    amount: client.totalCharged,
                    tint: colors.charge,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Paid',
                    amount: client.totalPaid,
                    tint: colors.payment,
                  ),
                ),
                Expanded(
                  child: _CollectionRate(client: client),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.amount,
    required this.tint,
  });

  final String label;
  final int amount;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
          color: tint,
          shape: BoxShape.circle,
        )),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelSmall),
              MoneyText(
                amount,
                absolute: true,
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                semanticsPrefix: 'Total $label',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Share of everything charged that has actually been collected.
class _CollectionRate extends StatelessWidget {
  const _CollectionRate({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    if (client.totalCharged <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collected', style: context.text.labelSmall),
          Text('-', style: context.text.labelMedium),
        ],
      );
    }

    final ratio = (client.totalPaid / client.totalCharged).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Collected', style: context.text.labelSmall),
        Row(
          children: [
            Text(
              '$percent%',
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: context.colors.surfaceSunken,
                  color: context.colors.payment,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
