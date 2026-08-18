import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/app_transaction.dart';
import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/portal_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../core/utils/safe_insets.dart';

/// Everything recorded about one transaction, plus the ways to correct it.
///
/// Corrections favour a compensating entry over destruction. A reversal leaves
/// both the original and the correction visible, which is what makes the
/// balance defensible months later.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key,
    required this.clientId,
    required this.transactionId,
  });

  final String clientId;
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(clientTransactionsProvider(clientId));
    final client = ref.watch(clientByIdProvider(clientId));
    final projects = ref.watch(projectsByIdProvider(clientId));

    return transactionsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: error),
      ),
      data: (all) {
        final index = all.indexWhere((t) => t.id == transactionId);
        if (index == -1) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction not found',
              message: 'It may have been deleted.',
              action: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ),
          );
        }

        final tx = all[index];
        // The list is newest-first, so the entry this one superseded sits after
        // it. Needed to restore the client's pointer if it gets deleted.
        final previous = index + 1 < all.length ? all[index + 1] : null;
        final isLatest = index == 0;

        return _TransactionDetailView(
          transaction: tx,
          previous: previous,
          isLatest: isLatest,
          clientName: client?.name ?? '',
          projectName: projects[tx.projectId]?.name,
          reversal: tx.reversedById == null
              ? null
              : all.where((t) => t.id == tx.reversedById).firstOrNull,
          reversedOriginal: tx.reversesId == null
              ? null
              : all.where((t) => t.id == tx.reversesId).firstOrNull,
        );
      },
    );
  }
}

class _TransactionDetailView extends ConsumerStatefulWidget {
  const _TransactionDetailView({
    required this.transaction,
    required this.previous,
    required this.isLatest,
    required this.clientName,
    required this.projectName,
    required this.reversal,
    required this.reversedOriginal,
  });

  final AppTransaction transaction;
  final AppTransaction? previous;
  final bool isLatest;
  final String clientName;
  final String? projectName;

  /// The entry that reversed this one, if any.
  final AppTransaction? reversal;

  /// The entry this one reverses, if this is a reversal.
  final AppTransaction? reversedOriginal;

  @override
  ConsumerState<_TransactionDetailView> createState() =>
      _TransactionDetailViewState();
}

class _TransactionDetailViewState
    extends ConsumerState<_TransactionDetailView> {
  bool _busy = false;

  AppTransaction get tx => widget.transaction;

  Future<void> _reverse() async {
    final currency = ref.read(currencyProvider);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reverse this transaction?',
      message:
          'This does not delete anything. A compensating entry is added that '
          'cancels this one out, and both stay in the history.',
      confirmLabel: 'Reverse',
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A ${tx.type.label.toLowerCase()} of '
            '${Money.format(tx.amount, currency: currency)} will be cancelled.',
          ),
          const SizedBox(height: 4),
          Text(
            'The balance moves by '
            '${Money.format(-tx.delta, currency: currency, signed: true)}.',
          ),
        ],
      ),
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(transactionServiceProvider)
          .reverse(
            uid: ref.read(requireUidProvider),
            clientId: tx.clientId,
            original: tx,
            actorName: ref.read(actorNameProvider),
          );
      syncSharePage(ref, tx.clientId);
      if (!mounted) return;
      context.pop();
      AppToast.success(context, 'Transaction reversed');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete permanently?',
      message:
          'This erases the entry with no trace in the history. Reversing is '
          'usually the better choice, because it corrects the balance and keeps the '
          'record of what happened.',
      confirmLabel: 'Delete forever',
      destructive: true,
      detail: const Text(
        'Only the newest entry can be deleted, because anything earlier would '
        'invalidate the running balances recorded after it.',
      ),
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(transactionServiceProvider)
          .deleteLatest(
            uid: ref.read(requireUidProvider),
            clientId: tx.clientId,
            tx: tx,
            previous: widget.previous,
          );
      syncSharePage(ref, tx.clientId);
      if (!mounted) return;
      context.pop();
      AppToast.success(context, 'Transaction deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  Future<void> _editDetails() async {
    final result = await showModalBottomSheet<({String note, String method})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditDetailsSheet(transaction: tx),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(transactionServiceProvider)
          .editDetails(
            uid: ref.read(requireUidProvider),
            clientId: tx.clientId,
            transactionId: tx.id,
            note: result.note,
            paymentMethod: result.method,
            projectId: tx.projectId,
          );
      syncSharePage(ref, tx.clientId);
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.success(context, 'Details updated');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = colors.forDelta(tx.delta);
    final canReverse = !tx.isReversed && !tx.isReversal;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, context.scrollBottomPadding()),
        children: [
          _AmountHeader(transaction: tx, tint: tint),
          const SizedBox(height: 16),

          if (tx.isReversed) _ReversedBanner(reversal: widget.reversal),
          if (tx.isReversal && widget.reversedOriginal != null)
            _ReversalBanner(original: widget.reversedOriginal!),

          AppCard(
            child: Column(
              children: [
                DetailRow(
                  label: 'Type',
                  child: Row(
                    children: [
                      Text(tx.type.label),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.delta >= 0 ? 'Increases balance' : 'Reduces balance',
                          style: context.text.labelSmall?.copyWith(
                            color: tint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Client',
                  child: Text(
                    widget.clientName.isEmpty ? '-' : widget.clientName,
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Description',
                  child: Text(tx.note.trim().isEmpty ? '-' : tx.note.trim()),
                ),
                if (widget.projectName != null) ...[
                  Divider(height: 1, color: colors.hairline),
                  DetailRow(
                    label: 'Project',
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: context.scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(widget.projectName!),
                      ],
                    ),
                  ),
                ],
                if (tx.paymentMethod.trim().isNotEmpty) ...[
                  Divider(height: 1, color: colors.hairline),
                  DetailRow(
                    label: 'Method',
                    child: Text(tx.paymentMethod.trim()),
                  ),
                ],
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Date',
                  child: Text(
                    tx.createdAt == null
                        ? 'Saving…'
                        : AppDate.dayWithWeekday(tx.createdAt!),
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Time',
                  child: Text(
                    tx.createdAt == null ? '-' : AppDate.time(tx.createdAt!),
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Balance after',
                  trailing: BalanceStatusChip(
                    balance: tx.runningBalance,
                    dense: true,
                  ),
                  child: MoneyText(
                    tx.runningBalance,
                    absolute: true,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Created by',
                  child: Text(
                    tx.createdByName.isEmpty ? 'You' : tx.createdByName,
                  ),
                ),
                if (tx.wasEdited) ...[
                  Divider(height: 1, color: colors.hairline),
                  DetailRow(
                    label: 'Edited',
                    child: Text(
                      '${AppDate.full(tx.editedAt!)}\n'
                      'Only the description was changed.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
                Divider(height: 1, color: colors.hairline),
                DetailRow(
                  label: 'Transaction ID',
                  trailing: IconButton(
                    tooltip: 'Copy ID',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: tx.id));
                      if (context.mounted) {
                        AppToast.success(context, 'Transaction ID copied');
                      }
                    },
                  ),
                  child: Text(
                    tx.id,
                    style: context.text.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Corrections',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Amounts and types are never edited in place, because changing one would '
            'invalidate every balance recorded after it.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _busy ? null : _editDetails,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Edit description'),
          ),
          const SizedBox(height: 10),

          if (canReverse)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: context.scheme.primary,
              ),
              onPressed: _busy ? null : _reverse,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text('Reverse transaction'),
            ),

          if (widget.isLatest) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: context.scheme.error,
              ),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete permanently'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Available because this is the newest entry for this client.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountHeader extends StatelessWidget {
  const _AmountHeader({required this.transaction, required this.tint});

  final AppTransaction transaction;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.colors.surfaceForDelta(transaction.delta),
      borderColor: tint.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.type.label,
            style: context.text.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                transaction.signPrefix,
                style: context.text.displaySmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    transaction.amount,
                    absolute: true,
                    style: context.text.displaySmall,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
          if (transaction.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(transaction.note.trim(), style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ReversedBanner extends StatelessWidget {
  const _ReversedBanner({required this.reversal});

  final AppTransaction? reversal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.undo_rounded,
              size: 18,
              color: context.scheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This transaction was reversed',
                    style: context.text.titleSmall?.copyWith(
                      color: context.scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reversal?.createdAt == null
                        ? 'Its effect on the balance has been cancelled out.'
                        : 'Cancelled on ${AppDate.full(reversal!.createdAt!)}.',
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onErrorContainer,
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

class _ReversalBanner extends StatelessWidget {
  const _ReversalBanner({required this.original});

  final AppTransaction original;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: context.scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This entry cancels a ${original.type.label.toLowerCase()} '
                'recorded on '
                '${original.createdAt == null ? 'an earlier date' : AppDate.day(original.createdAt!)}.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the description and payment method only.
class _EditDetailsSheet extends StatefulWidget {
  const _EditDetailsSheet({required this.transaction});

  final AppTransaction transaction;

  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  late final _note = TextEditingController(text: widget.transaction.note);
  late final _method = TextEditingController(
    text: widget.transaction.paymentMethod,
  );

  @override
  void dispose() {
    _note.dispose();
    _method.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPayment = widget.transaction.type == TxType.payment;

    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, context.sheetBottomPadding()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit description', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'The amount and type stay as recorded. To change those, reverse '
              'this entry and add a new one.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _note,
              autofocus: true,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                counterText: '',
              ),
            ),
            if (isPayment) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _method,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  counterText: '',
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  note: _note.text,
                  method: _method.text,
                )),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
