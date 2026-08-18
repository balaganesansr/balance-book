import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client.dart';
import '../models/enums.dart';
import 'app_providers.dart';
import 'auth_providers.dart';

/// Every client the user owns, live.
///
/// One subscription feeds the client list, the dashboard totals, search and the
/// client picker. Nothing else needs to query the clients collection.
final clientsProvider = StreamProvider<List<Client>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Client>[]);
  return ref.watch(clientServiceProvider).watchAll(uid);
});

/// Clients that have not been archived. The default working set.
final activeClientsProvider = Provider<List<Client>>((ref) {
  final clients = ref.watch(clientsProvider).value ?? const <Client>[];
  return clients.where((c) => !c.isArchived).toList(growable: false);
});

/// A single client, read from the list already in memory so opening a profile
/// is instant and needs no extra read.
final clientByIdProvider = Provider.family<Client?, String>((ref, clientId) {
  final clients = ref.watch(clientsProvider).value;
  if (clients == null) return null;
  for (final c in clients) {
    if (c.id == clientId) return c;
  }
  return null;
});

// --- Search and filtering ---------------------------------------------------

enum ClientFilter { all, owes, settled, credit, recent, favorites, archived }

extension ClientFilterX on ClientFilter {
  String get label => switch (this) {
    ClientFilter.all => 'All',
    ClientFilter.owes => 'Owes me',
    ClientFilter.settled => 'Settled',
    ClientFilter.credit => 'Credit',
    ClientFilter.recent => 'Recent',
    ClientFilter.favorites => 'Favorites',
    ClientFilter.archived => 'Archived',
  };
}

enum ClientSort { balance, name, recent }

extension ClientSortX on ClientSort {
  String get label => switch (this) {
    ClientSort.balance => 'Highest balance',
    ClientSort.name => 'Name (A–Z)',
    ClientSort.recent => 'Recent activity',
  };
}

class ClientSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final clientSearchProvider =
    NotifierProvider<ClientSearchQuery, String>(ClientSearchQuery.new);

class ClientFilterNotifier extends Notifier<ClientFilter> {
  @override
  ClientFilter build() => ClientFilter.all;

  void set(ClientFilter value) => state = value;
}

final clientFilterProvider =
    NotifierProvider<ClientFilterNotifier, ClientFilter>(
      ClientFilterNotifier.new,
    );

class ClientSortNotifier extends Notifier<ClientSort> {
  @override
  ClientSort build() => ClientSort.balance;

  void set(ClientSort value) => state = value;
}

final clientSortProvider =
    NotifierProvider<ClientSortNotifier, ClientSort>(ClientSortNotifier.new);

/// Reports keeps its own sort so changing the order of a report does not
/// silently reorder the client list on the other tab.
final reportSortProvider =
    NotifierProvider<ClientSortNotifier, ClientSort>(ClientSortNotifier.new);

/// Considered "recently active" for the Recent filter.
const _recentWindow = Duration(days: 7);

/// The client list as shown on screen: filtered, searched and sorted.
///
/// All of it happens in memory over the already-loaded list, which is what
/// makes search feel instant, with no query round-trip per keystroke, so no
/// debouncing is needed either.
final filteredClientsProvider = Provider<List<Client>>((ref) {
  final all = ref.watch(clientsProvider).value ?? const <Client>[];
  final filter = ref.watch(clientFilterProvider);
  final sort = ref.watch(clientSortProvider);
  final query = ref.watch(clientSearchProvider).trim().toLowerCase();

  final cutoff = DateTime.now().subtract(_recentWindow);

  var result = all.where((c) {
    // Archived clients stay out of every view except their own filter, but
    // their history is always reachable by opening them directly.
    if (filter != ClientFilter.archived && c.isArchived) return false;

    return switch (filter) {
      ClientFilter.all => true,
      ClientFilter.owes => c.currentBalance > 0,
      ClientFilter.settled => c.currentBalance == 0,
      ClientFilter.credit => c.currentBalance < 0,
      ClientFilter.recent =>
        c.lastActivityAt != null && c.lastActivityAt!.isAfter(cutoff),
      ClientFilter.favorites => c.isFavorite,
      ClientFilter.archived => c.isArchived,
    };
  });

  if (query.isNotEmpty) {
    final digits = Client.normalisePhoneForSearch(query);
    result = result.where((c) {
      if (c.searchHaystack.contains(query)) return true;
      // Let a user find "98765 43210" by typing "9876543210".
      return digits.isNotEmpty &&
          Client.normalisePhoneForSearch(c.phone).contains(digits);
    });
  }

  final list = result.toList();
  list.sort((a, b) {
    // Favourites always float to the top, whatever the sort.
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    return switch (sort) {
      ClientSort.balance => b.currentBalance.compareTo(a.currentBalance),
      ClientSort.name => a.nameLower.compareTo(b.nameLower),
      ClientSort.recent => (b.lastActivityAt ?? DateTime(0)).compareTo(
        a.lastActivityAt ?? DateTime(0),
      ),
    };
  });
  return List.unmodifiable(list);
});

/// Recently opened clients, newest first, skipping any that no longer exist.
final recentClientsProvider = Provider<List<Client>>((ref) {
  final ids = ref.watch(recentClientIdsProvider);
  final clients = ref.watch(clientsProvider).value ?? const <Client>[];
  if (ids.isEmpty || clients.isEmpty) return const <Client>[];

  final byId = {for (final c in clients) c.id: c};
  return [for (final id in ids) ?byId[id]];
});

/// Ids of recently viewed clients, kept on the device.
class RecentClientIds extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(prefsProvider).recentClientIds;

  Future<void> touch(String clientId) async {
    await ref.read(prefsProvider).touchClient(clientId);
    state = ref.read(prefsProvider).recentClientIds;
  }

  Future<void> forget(String clientId) async {
    await ref.read(prefsProvider).forgetClient(clientId);
    state = ref.read(prefsProvider).recentClientIds;
  }
}

final recentClientIdsProvider =
    NotifierProvider<RecentClientIds, List<String>>(RecentClientIds.new);

// --- Dashboard totals -------------------------------------------------------

/// Headline numbers for the dashboard, summed from the client list already in
/// memory. Archived clients are excluded so the totals match what is on screen.
class PortfolioTotals {
  const PortfolioTotals({
    required this.outstanding,
    required this.credit,
    required this.clientsWithDues,
    required this.clientsInCredit,
    required this.settledClients,
    required this.totalClients,
  });

  /// Sum of all positive balances, what the user is owed in total.
  final int outstanding;

  /// Sum of all negative balances, as a positive number.
  final int credit;

  final int clientsWithDues;
  final int clientsInCredit;
  final int settledClients;
  final int totalClients;

  bool get isEmpty => totalClients == 0;

  static const empty = PortfolioTotals(
    outstanding: 0,
    credit: 0,
    clientsWithDues: 0,
    clientsInCredit: 0,
    settledClients: 0,
    totalClients: 0,
  );
}

final portfolioTotalsProvider = Provider<PortfolioTotals>((ref) {
  final clients = ref.watch(activeClientsProvider);
  if (clients.isEmpty) return PortfolioTotals.empty;

  var outstanding = 0;
  var credit = 0;
  var withDues = 0;
  var inCredit = 0;
  var settled = 0;

  for (final c in clients) {
    if (c.currentBalance > 0) {
      outstanding += c.currentBalance;
      withDues++;
    } else if (c.currentBalance < 0) {
      credit += -c.currentBalance;
      inCredit++;
    } else {
      settled++;
    }
  }

  return PortfolioTotals(
    outstanding: outstanding,
    credit: credit,
    clientsWithDues: withDues,
    clientsInCredit: inCredit,
    settledClients: settled,
    totalClients: clients.length,
  );
});

/// Clients owing the most, for the dashboard's "Top outstanding" list.
final topOutstandingProvider = Provider<List<Client>>((ref) {
  final clients = [...ref.watch(activeClientsProvider)]
      .where((c) => c.currentBalance > 0)
      .toList()
    ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
  return clients.take(5).toList(growable: false);
});

/// Clients sorted for the "Client performance" report.
final clientPerformanceProvider =
    Provider.family<List<Client>, ClientSort>((ref, sort) {
  final clients = [...ref.watch(activeClientsProvider)];
  clients.sort((a, b) => switch (sort) {
    ClientSort.balance => b.currentBalance.compareTo(a.currentBalance),
    ClientSort.name => a.nameLower.compareTo(b.nameLower),
    ClientSort.recent => (b.lastActivityAt ?? DateTime(0)).compareTo(
      a.lastActivityAt ?? DateTime(0),
    ),
  });
  return List.unmodifiable(clients);
});

/// Statuses derived for a client, used by chips and badges.
BalanceState balanceStateOf(Client client) => client.balanceState;
