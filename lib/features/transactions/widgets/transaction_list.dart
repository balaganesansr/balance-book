import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../models/app_transaction.dart';
import 'transaction_item.dart';

/// A transaction and everything needed to render its row without extra lookups.
class TransactionRow {
  const TransactionRow({
    required this.transaction,
    this.clientName,
    this.projectName,
  });

  final AppTransaction transaction;
  final String? clientName;
  final String? projectName;
}

/// Date-grouped transaction list.
///
/// Groups under "Today" / "Yesterday" / a date, which is how people actually
/// recall when something happened. Emits slivers so it can sit inside a
/// scrolling screen without a nested scroll view.
class TransactionSliverList extends StatelessWidget {
  const TransactionSliverList({
    super.key,
    required this.rows,
    this.onTap,
    this.showRunningBalance = true,
  });

  final List<TransactionRow> rows;
  final void Function(AppTransaction transaction)? onTap;
  final bool showRunningBalance;

  @override
  Widget build(BuildContext context) {
    final grouped = groupByDay(rows);

    return SliverList.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        return _DayGroup(
          header: entry.header,
          rows: entry.rows,
          onTap: onTap,
          showRunningBalance: showRunningBalance,
        );
      },
    );
  }

  /// Splits rows into day buckets, preserving the incoming (newest first)
  /// order within each day.
  static List<({String header, List<TransactionRow> rows})> groupByDay(
    List<TransactionRow> rows,
  ) {
    final result = <({String header, List<TransactionRow> rows})>[];
    String? currentHeader;
    var bucket = <TransactionRow>[];

    for (final row in rows) {
      final header = AppDate.groupHeader(row.transaction.effectiveDate);
      if (header != currentHeader) {
        if (currentHeader != null) {
          result.add((header: currentHeader, rows: bucket));
        }
        currentHeader = header;
        bucket = <TransactionRow>[];
      }
      bucket.add(row);
    }
    if (currentHeader != null && bucket.isNotEmpty) {
      result.add((header: currentHeader, rows: bucket));
    }
    return result;
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.header,
    required this.rows,
    required this.onTap,
    required this.showRunningBalance,
  });

  final String header;
  final List<TransactionRow> rows;
  final void Function(AppTransaction transaction)? onTap;
  final bool showRunningBalance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            header,
            style: context.text.labelMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 58),
                    child: Divider(height: 1, color: colors.hairline),
                  ),
                TransactionItem(
                  transaction: rows[i].transaction,
                  clientName: rows[i].clientName,
                  projectName: rows[i].projectName,
                  showRunningBalance: showRunningBalance,
                  onTap: onTap == null
                      ? null
                      : () => onTap!(rows[i].transaction),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Non-sliver variant for short embedded lists, such as the dashboard strip.
class TransactionListView extends StatelessWidget {
  const TransactionListView({
    super.key,
    required this.rows,
    this.onTap,
    this.showRunningBalance = false,
  });

  final List<TransactionRow> rows;
  final void Function(AppTransaction transaction)? onTap;
  final bool showRunningBalance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Divider(height: 1, color: colors.hairline),
              ),
            TransactionItem(
              transaction: rows[i].transaction,
              clientName: rows[i].clientName,
              projectName: rows[i].projectName,
              showRunningBalance: showRunningBalance,
              dense: true,
              onTap: onTap == null ? null : () => onTap!(rows[i].transaction),
            ),
          ],
        ],
      ),
    );
  }
}
