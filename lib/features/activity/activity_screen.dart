import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/date_filter.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/app_transaction.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../providers/client_providers.dart';
import '../../providers/transaction_providers.dart';
import '../clients/widgets/client_picker.dart';
import '../transactions/widgets/transaction_list.dart';

/// Every transaction across every client, filterable by type, client and date.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activityFilterProvider);
    final activityAsync = ref.watch(activityProvider(filter));
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final byId = {for (final c in clients) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          if (filter.isFiltered)
            TextButton(
              onPressed: () => ref.read(activityFilterProvider.notifier).reset(),
              child: const Text('Clear'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _TypeFilter(filter: filter),
          DateFilterBar(
            value: filter.range,
            onChanged: (range) =>
                ref.read(activityFilterProvider.notifier).setRange(range),
          ),
          const SizedBox(height: 8),
          _ClientFilterRow(filter: filter, clients: byId),
          Expanded(
            child: activityAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SkeletonList(count: 5),
              ),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(activityProvider(filter)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_rounded,
                    title: filter.isFiltered
                        ? 'Nothing in this view'
                        : 'No activity yet',
                    message: filter.isFiltered
                        ? 'No transactions match these filters. Try widening '
                              'the date range.'
                        : 'Charges and payments across all your clients will '
                              'appear here.',
                    action: filter.isFiltered
                        ? TextButton(
                            onPressed: () => ref
                                .read(activityFilterProvider.notifier)
                                .reset(),
                            child: const Text('Clear filters'),
                          )
                        : null,
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _PeriodSummary(transactions: list),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: TransactionSliverList(
                        showRunningBalance: false,
                        rows: [
                          for (final tx in list)
                            TransactionRow(
                              transaction: tx,
                              clientName:
                                  byId[tx.clientId]?.name ?? 'Deleted client',
                            ),
                        ],
                        onTap: (tx) => context.push(
                          '/clients/${tx.clientId}/tx/${tx.id}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilter extends ConsumerWidget {
  const _TypeFilter({required this.filter});

  final ActivityFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = <({String label, TxType? type})>[
      (label: 'All', type: null),
      (label: 'Charges', type: TxType.charge),
      (label: 'Payments', type: TxType.payment),
      (label: 'Opening', type: TxType.opening),
      (label: 'Adjustments', type: TxType.adjustment),
      (label: 'Reversals', type: TxType.reversal),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(option.label),
                selected: filter.type == option.type,
                onSelected: (_) => ref
                    .read(activityFilterProvider.notifier)
                    .setType(option.type),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientFilterRow extends ConsumerWidget {
  const _ClientFilterRow({required this.filter, required this.clients});

  final ActivityFilter filter;
  final Map<String, Client> clients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = filter.clientId == null ? null : clients[filter.clientId];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () async {
                final client = await showClientPicker(
                  context,
                  title: 'Filter by client',
                );
                if (client != null) {
                  ref
                      .read(activityFilterProvider.notifier)
                      .setClient(client.id);
                }
              },
              icon: const Icon(Icons.person_search_outlined, size: 18),
              label: Text(
                selected?.name ?? 'All clients',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (filter.clientId != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Show all clients',
              onPressed: () =>
                  ref.read(activityFilterProvider.notifier).setClient(null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// In / out totals for exactly what is listed below.
class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({required this.transactions});

  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    var charges = 0;
    var payments = 0;
    for (final tx in transactions) {
      if (tx.delta > 0) {
        charges += tx.delta;
      } else {
        payments += -tx.delta;
      }
    }

    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _SummaryCell(
              label: 'Charged',
              amount: charges,
              tint: colors.charge,
            ),
            Container(width: 1, height: 26, color: colors.hairline),
            _SummaryCell(
              label: 'Received',
              amount: payments,
              tint: colors.payment,
            ),
            Container(width: 1, height: 26, color: colors.hairline),
            Expanded(
              child: Column(
                children: [
                  Text('Entries', style: context.text.labelSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${transactions.length}',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.tint,
  });

  final String label;
  final int amount;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: 3),
          MoneyText(
            amount,
            absolute: true,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            color: tint,
            semanticsPrefix: 'Total $label',
          ),
        ],
      ),
    );
  }
}

/// Formats the range for the app bar subtitle.
String describeRange(DateRange range) =>
    range.preset == DatePreset.all ? 'All time' : range.label;
