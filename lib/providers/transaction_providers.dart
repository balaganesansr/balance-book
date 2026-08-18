import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_date.dart';
import '../models/app_transaction.dart';
import '../models/enums.dart';
import '../models/project.dart';
import 'app_providers.dart';
import 'auth_providers.dart';

/// A client's full ledger, newest first.
final clientTransactionsProvider =
    StreamProvider.family<List<AppTransaction>, String>((ref, clientId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <AppTransaction>[]);
  return ref.watch(transactionServiceProvider).watchForClient(uid, clientId);
});

/// A client's projects. Labels only, these never carry a balance.
final clientProjectsProvider =
    StreamProvider.family<List<Project>, String>((ref, clientId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Project>[]);
  return ref.watch(projectServiceProvider).watchForClient(uid, clientId);
});

/// Projects keyed by id, for resolving a transaction's label.
final projectsByIdProvider =
    Provider.family<Map<String, Project>, String>((ref, clientId) {
  final projects = ref.watch(clientProjectsProvider(clientId)).value;
  if (projects == null) return const {};
  return {for (final p in projects) p.id: p};
});

/// Which project the client's history is filtered to. `null` = all.
class ProjectFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? projectId) => state = projectId;
  void clear() => state = null;
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterNotifier, String?>(ProjectFilterNotifier.new);

// --- Global activity --------------------------------------------------------

/// Everything the Activity screen and the period reports filter on.
@immutable
class ActivityFilter {
  const ActivityFilter({
    this.type,
    this.clientId,
    this.range = DateRange.all,
    this.limit = 200,
  });

  /// `null` shows charges and payments alike.
  final TxType? type;

  /// `null` spans every client.
  final String? clientId;

  final DateRange range;
  final int limit;

  ActivityFilter copyWith({
    TxType? type,
    bool clearType = false,
    String? clientId,
    bool clearClient = false,
    DateRange? range,
    int? limit,
  }) => ActivityFilter(
    type: clearType ? null : (type ?? this.type),
    clientId: clearClient ? null : (clientId ?? this.clientId),
    range: range ?? this.range,
    limit: limit ?? this.limit,
  );

  bool get isFiltered =>
      type != null || clientId != null || range.preset != DatePreset.all;

  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.type == type &&
      other.clientId == clientId &&
      other.range == range &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(type, clientId, range, limit);
}

class ActivityFilterNotifier extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => const ActivityFilter();

  void setType(TxType? type) =>
      state = state.copyWith(type: type, clearType: type == null);

  void setClient(String? clientId) =>
      state = state.copyWith(clientId: clientId, clearClient: clientId == null);

  void setRange(DateRange range) => state = state.copyWith(range: range);

  void reset() => state = const ActivityFilter();
}

final activityFilterProvider =
    NotifierProvider<ActivityFilterNotifier, ActivityFilter>(
      ActivityFilterNotifier.new,
    );

/// Transactions across every client, matching [filter].
///
/// Two different queries back this, and the difference matters:
///
///  * No client filter: a collection-group query over every transaction the
///    user owns, capped at [ActivityFilter.limit] and constrained by type and
///    date in Firestore (see `firestore.indexes.json`).
///  * A client filter: that client's own subcollection, with type and date
///    applied in memory. Filtering the capped global feed down to one client
///    instead would quietly hide their older entries whenever the cap was hit,
///    which would look like missing history rather than a truncated feed.
final activityProvider =
    StreamProvider.family<List<AppTransaction>, ActivityFilter>((ref, filter) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <AppTransaction>[]);
  final service = ref.watch(transactionServiceProvider);

  if (filter.clientId != null) {
    return service.watchForClient(uid, filter.clientId!).map((list) {
      return list.where((tx) {
        if (filter.type != null && tx.type != filter.type) return false;
        if (tx.createdAt == null) return true; // not yet confirmed
        return filter.range.contains(tx.createdAt!);
      }).toList(growable: false);
    });
  }

  return service.watchAll(
    uid,
    limit: filter.limit,
    type: filter.type,
    from: filter.range.start,
    to: filter.range.end,
  );
});

/// The dashboard's "recent activity" strip.
final recentActivityProvider = StreamProvider<List<AppTransaction>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <AppTransaction>[]);
  return ref.watch(transactionServiceProvider).watchAll(uid, limit: 8);
});

// --- Period totals ----------------------------------------------------------

/// Money in and money out over a period.
@immutable
class PeriodTotals {
  const PeriodTotals({
    required this.paymentsReceived,
    required this.chargesAdded,
    required this.paymentCount,
    required this.chargeCount,
    required this.truncated,
  });

  final int paymentsReceived;
  final int chargesAdded;
  final int paymentCount;
  final int chargeCount;

  /// True when the query hit its row cap, so the totals under-report. The UI
  /// says so rather than presenting a number that looks complete but is not.
  final bool truncated;

  int get net => chargesAdded - paymentsReceived;

  static const empty = PeriodTotals(
    paymentsReceived: 0,
    chargesAdded: 0,
    paymentCount: 0,
    chargeCount: 0,
    truncated: false,
  );
}

/// Row cap for period queries. Comfortably above a normal month for this kind
/// of business, and [PeriodTotals.truncated] flags the rare case it is hit.
const periodQueryLimit = 1000;

/// Totals for a period, summed from the transactions in that range.
///
/// Reversals are included through their signed `delta`, so a reversed charge
/// correctly cancels out of "charges added" rather than inflating both columns.
final periodTotalsProvider =
    StreamProvider.family<PeriodTotals, DateRange>((ref, range) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(PeriodTotals.empty);

  return ref
      .watch(transactionServiceProvider)
      .watchAll(
        uid,
        limit: periodQueryLimit,
        from: range.start,
        to: range.end,
      )
      .map((list) {
        var payments = 0;
        var charges = 0;
        var paymentCount = 0;
        var chargeCount = 0;

        for (final tx in list) {
          if (tx.delta > 0) {
            charges += tx.delta;
            if (tx.type != TxType.reversal) chargeCount++;
          } else if (tx.delta < 0) {
            payments += -tx.delta;
            if (tx.type != TxType.reversal) paymentCount++;
          }
        }

        return PeriodTotals(
          paymentsReceived: payments,
          chargesAdded: charges,
          paymentCount: paymentCount,
          chargeCount: chargeCount,
          truncated: list.length >= periodQueryLimit,
        );
      });
});

/// The period the dashboard and reports are showing.
class ReportRangeNotifier extends Notifier<DateRange> {
  @override
  DateRange build() => DateRange.of(DatePreset.month);

  void set(DateRange range) => state = range;
  void setPreset(DatePreset preset) => state = DateRange.of(preset);
}

final reportRangeProvider =
    NotifierProvider<ReportRangeNotifier, DateRange>(ReportRangeNotifier.new);
