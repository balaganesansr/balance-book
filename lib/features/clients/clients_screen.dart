import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/client.dart';
import '../../providers/client_providers.dart';
import 'widgets/client_card.dart';
import 'widgets/client_search_field.dart';

/// The searchable client list.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final clients = ref.watch(filteredClientsProvider);
    final filter = ref.watch(clientFilterProvider);
    final sort = ref.watch(clientSortProvider);
    final query = ref.watch(clientSearchProvider);
    final hasAny = (clientsAsync.value ?? const <Client>[]).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          PopupMenuButton<ClientSort>(
            tooltip: 'Sort clients',
            icon: const Icon(Icons.swap_vert_rounded),
            position: PopupMenuPosition.under,
            onSelected: (value) =>
                ref.read(clientSortProvider.notifier).set(value),
            itemBuilder: (context) => [
              for (final option in ClientSort.values)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        sort == option
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: sort == option
                            ? context.scheme.primary
                            : context.scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(option.label),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clients/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add client'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: ClientSearchField(
              value: query,
              onChanged: (v) => ref.read(clientSearchProvider.notifier).set(v),
            ),
          ),
          const _FilterChips(),
          const SizedBox(height: 4),
          Expanded(
            child: clientsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SkeletonList(count: 6),
              ),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(clientsProvider),
              ),
              data: (_) {
                if (!hasAny) return const _NoClientsYet();
                if (clients.isEmpty) {
                  return _NoMatches(
                    query: query,
                    filter: filter,
                    onClear: () {
                      ref.read(clientSearchProvider.notifier).clear();
                      ref
                          .read(clientFilterProvider.notifier)
                          .set(ClientFilter.all);
                    },
                  );
                }
                return _ClientList(clients: clients);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientList extends ConsumerWidget {
  const _ClientList({required this.clients});

  final List<Client> clients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Totals for exactly what is on screen, so a filtered view still answers
    // "how much is this worth".
    final total = clients.fold<int>(
      0,
      (sum, c) => c.currentBalance > 0 ? sum + c.currentBalance : sum,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: clients.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == clients.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${clients.length} ${clients.length == 1 ? 'client' : 'clients'} · ',
                  style: context.text.bodySmall,
                ),
                MoneyText(
                  total,
                  absolute: true,
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  color: context.scheme.onSurfaceVariant,
                ),
                Text(' outstanding', style: context.text.bodySmall),
              ],
            ),
          );
        }

        final client = clients[index];
        return ClientCard(
          client: client,
          onTap: () => context.push('/clients/${client.id}'),
        );
      },
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(clientFilterProvider);
    final all = ref.watch(clientsProvider).value ?? const <Client>[];

    int countFor(ClientFilter filter) => switch (filter) {
      ClientFilter.all => all.where((c) => !c.isArchived).length,
      ClientFilter.owes =>
        all.where((c) => !c.isArchived && c.currentBalance > 0).length,
      ClientFilter.settled =>
        all.where((c) => !c.isArchived && c.currentBalance == 0).length,
      ClientFilter.credit =>
        all.where((c) => !c.isArchived && c.currentBalance < 0).length,
      ClientFilter.recent => all
          .where(
            (c) =>
                !c.isArchived &&
                c.lastActivityAt != null &&
                c.lastActivityAt!.isAfter(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
          )
          .length,
      ClientFilter.favorites =>
        all.where((c) => !c.isArchived && c.isFavorite).length,
      ClientFilter.archived => all.where((c) => c.isArchived).length,
    };

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final filter in ClientFilter.values) ...[
            if (filter != ClientFilter.archived || countFor(filter) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${filter.label} · ${countFor(filter)}'),
                  selected: selected == filter,
                  onSelected: (_) =>
                      ref.read(clientFilterProvider.notifier).set(filter),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoClientsYet extends StatelessWidget {
  const _NoClientsYet();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No clients yet',
      message:
          'Add your first client to start tracking what they owe you.',
      action: FilledButton.icon(
        onPressed: () => context.push('/clients/new'),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add client'),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({
    required this.query,
    required this.filter,
    required this.onClear,
  });

  final String query;
  final ClientFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: query.isEmpty ? 'Nothing in ${filter.label}' : 'No matches',
      message: query.isEmpty
          ? 'No clients fall into this filter right now.'
          : 'No client matches “$query”. Try a name, company or phone number.',
      action: TextButton(onPressed: onClear, child: const Text('Clear filters')),
    );
  }
}
