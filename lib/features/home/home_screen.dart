import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/client_avatar.dart';
import '../../core/widgets/date_filter.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/app_transaction.dart';
import '../../models/client.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/transaction_providers.dart';
import '../clients/widgets/client_card.dart';
import '../transactions/widgets/transaction_list.dart';

/// The dashboard.
///
/// Answers the one question the app exists for: how much am I owed, and by
/// whom, before anything else on screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final totals = ref.watch(portfolioTotalsProvider);
    final hasClients = (clientsAsync.value ?? const <Client>[]).isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clientsProvider);
            ref.invalidate(recentActivityProvider);
            await ref.read(clientsProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Greeting()),

              if (clientsAsync.isLoading && !hasClients)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
                )
              else if (!hasClients)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FirstRunEmptyState(),
                )
              else ...[
                SliverToBoxAdapter(child: _OutstandingHero(totals: totals)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(child: _PeriodSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: _RecentClientsStrip()),
                const SliverToBoxAdapter(child: _TopOutstanding()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: _RecentActivity()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final name = profile?.name.trim() ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: context.text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Your book' : name.split(' ').first,
                  style: context.text.headlineSmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: context.scheme.primaryContainer,
              child: Text(
                profile?.initials ?? '·',
                style: context.text.labelLarge?.copyWith(
                  color: context.scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The headline number.
class _OutstandingHero extends ConsumerWidget {
  const _OutstandingHero({required this.totals});

  final PortfolioTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = context.colors.heroGradient;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(clientFilterProvider.notifier).set(ClientFilter.owes);
            context.go('/clients');
          },
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total outstanding',
                        style: context.text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(
                      totals.outstanding,
                      style: context.text.displaySmall?.copyWith(
                        fontSize: 40,
                        height: 1.05,
                      ),
                      color: Colors.white,
                      semanticsPrefix: 'Total outstanding',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _HeroPill(
                        icon: Icons.people_alt_rounded,
                        label:
                            '${totals.clientsWithDues} '
                            '${totals.clientsWithDues == 1 ? 'client owes' : 'clients owe'}',
                      ),
                      const SizedBox(width: 8),
                      if (totals.credit > 0)
                        _HeroPill(
                          icon: Icons.savings_outlined,
                          label:
                              '${totals.clientsInCredit} in credit',
                        )
                      else
                        _HeroPill(
                          icon: Icons.check_circle_outline_rounded,
                          label: '${totals.settledClients} settled',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Payments received and charges added over the selected period.
class _PeriodSection extends ConsumerWidget {
  const _PeriodSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final totalsAsync = ref.watch(periodTotalsProvider(range));
    final totals = totalsAsync.value ?? PeriodTotals.empty;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: 'This period',
            padding: EdgeInsets.zero,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DateFilterButton(
                  value: range,
                  onChanged: (r) =>
                      ref.read(reportRangeProvider.notifier).set(r),
                ),
                IconButton(
                  tooltip: 'Reports',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.push('/reports'),
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Payments received',
                  icon: Icons.south_west_rounded,
                  tint: colors.payment,
                  caption:
                      '${totals.paymentCount} ${totals.paymentCount == 1 ? 'payment' : 'payments'}',
                  onTap: () => context.go('/activity'),
                  value: MoneyText(
                    totals.paymentsReceived,
                    absolute: true,
                    color: colors.payment,
                    semanticsPrefix: 'Payments received',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Charges added',
                  icon: Icons.north_east_rounded,
                  tint: colors.charge,
                  caption:
                      '${totals.chargeCount} ${totals.chargeCount == 1 ? 'charge' : 'charges'}',
                  onTap: () => context.go('/activity'),
                  value: MoneyText(
                    totals.chargesAdded,
                    absolute: true,
                    color: colors.charge,
                    semanticsPrefix: 'Charges added',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (totals.truncated)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Showing the most recent $periodQueryLimit transactions in this '
              'period, so totals may be incomplete. Narrow the range for exact '
              'figures.',
              style: context.text.labelSmall?.copyWith(color: colors.charge),
            ),
          ),
      ],
    );
  }
}

/// Shortcuts back to clients the user was just looking at.
class _RecentClientsStrip extends ConsumerWidget {
  const _RecentClientsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentClientsProvider);
    if (recent.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: SectionHeader(title: 'Jump back in', padding: EdgeInsets.zero),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final client = recent[index];
              return _RecentClientChip(client: client);
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RecentClientChip extends StatelessWidget {
  const _RecentClientChip({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Material(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/clients/${client.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClientAvatar.of(client, size: 32),
                const SizedBox(height: 6),
                Text(
                  client.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                MoneyText(
                  client.currentBalance,
                  absolute: true,
                  style: context.text.labelSmall,
                  color: context.colors.forState(client.balanceState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopOutstanding extends ConsumerWidget {
  const _TopOutstanding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topOutstandingProvider);
    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          color: context.colors.paymentSurface,
          borderColor: context.colors.payment.withValues(alpha: 0.22),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: context.colors.payment,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Everyone is settled up. Nothing outstanding right now.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.payment,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(
            title: 'Top outstanding',
            padding: EdgeInsets.zero,
            action: TextButton(
              onPressed: () {
                ref.read(clientFilterProvider.notifier).set(ClientFilter.owes);
                context.go('/clients');
              },
              child: const Text('See all'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 58),
                      child: Divider(
                        height: 1,
                        color: context.colors.hairline,
                      ),
                    ),
                  ClientMiniCard(
                    client: top[i],
                    onTap: () => context.push('/clients/${top[i].id}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final byId = {for (final c in clients) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(
            title: 'Recent activity',
            padding: EdgeInsets.zero,
            action: TextButton(
              onPressed: () => context.go('/activity'),
              child: const Text('See all'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: activityAsync.when(
            loading: () => const SkeletonList(count: 3),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(recentActivityProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  compact: true,
                  icon: Icons.history_rounded,
                  title: 'Nothing recorded yet',
                  message:
                      'Charges and payments you record will show up here.',
                );
              }
              return _ActivityCard(transactions: list, clientsById: byId);
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.transactions, required this.clientsById});

  final List<AppTransaction> transactions;
  final Map<String, Client> clientsById;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TransactionListView(
          rows: [
            for (final tx in transactions)
              TransactionRow(
                transaction: tx,
                clientName: clientsById[tx.clientId]?.name ?? 'Client',
              ),
          ],
          onTap: (tx) => context.push('/clients/${tx.clientId}/tx/${tx.id}'),
        ),
        if (transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Last updated ${AppDate.relative(transactions.first.effectiveDate)}',
              style: context.text.labelSmall,
            ),
          ),
      ],
    );
  }
}

/// What a brand new user sees.
class _FirstRunEmptyState extends StatelessWidget {
  const _FirstRunEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 76),
            const SizedBox(height: 22),
            Text(
              'Add your first client',
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Track balances, payments and extra work in one place, and '
              'always know exactly who owes you what.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 54),
              ),
              onPressed: () => context.push('/clients/new'),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Add client'),
            ),
          ],
        ),
      ),
    );
  }
}
