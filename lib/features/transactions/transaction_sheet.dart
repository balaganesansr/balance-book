import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/amount_field.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/offline_banner.dart';
import '../../models/app_transaction.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/project.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/portal_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../core/utils/safe_insets.dart';

/// Opens the add-charge / record-payment sheet.
///
/// Returns the new transaction's id when something was saved.
Future<String?> showTransactionSheet(
  BuildContext context, {
  required Client client,
  required TxType type,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TransactionSheet(client: client, type: type),
  );
}

/// Add Charge and Record Payment share this sheet. They differ only in sign,
/// wording and accent colour, and keeping them together guarantees they behave
/// identically.
///
/// The flow is built to be finished in a couple of seconds: the amount field
/// takes focus immediately, quick-amount chips cover round figures, and there
/// is no confirmation step, because a mistake is undone with a reversal, not
/// prevented with a dialog on every entry.
class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({
    super.key,
    required this.client,
    required this.type,
  });

  final Client client;
  final TxType type;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _methodController = TextEditingController();

  String? _projectId;
  bool _increase = true;

  /// Guards against a double tap firing two writes. The button is disabled as
  /// well, but the flag is what actually makes it safe.
  bool _saving = false;

  bool get _isPayment => widget.type == TxType.payment;
  bool get _isAdjustment => widget.type == TxType.adjustment;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _noteController.dispose();
    _methodController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  int? get _parsedAmount => Money.tryParse(
    _amountController.text,
    currency: ref.read(currencyProvider),
  );

  /// Signed effect of what is currently typed.
  int get _delta {
    final amount = _parsedAmount ?? 0;
    if (_isPayment) return -amount;
    if (_isAdjustment && !_increase) return -amount;
    return amount;
  }

  Color _accent(BuildContext context) =>
      _isPayment ? context.colors.payment : context.colors.charge;

  String get _title => switch (widget.type) {
    TxType.payment => 'Record payment',
    TxType.adjustment => 'Adjust balance',
    _ => 'Add charge',
  };

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = _parsedAmount;
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    try {
      final id = await ref
          .read(transactionServiceProvider)
          .add(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            draft: TxDraft(
              type: widget.type,
              amount: amount,
              note: _noteController.text,
              paymentMethod: _isPayment ? _methodController.text : '',
              projectId: _projectId,
              increase: _increase,
            ),
            actorName: ref.read(actorNameProvider),
          );

      // The ledger is committed; refresh the client's shared page in the
      // background. Never awaited, see syncSharePage.
      syncSharePage(ref, widget.client.id);

      if (!mounted) return;
      Navigator.of(context).pop(id);

      final newBalance = widget.client.currentBalance + _delta;
      AppToast.success(
        context,
        '${_isPayment ? 'Payment' : 'Charge'} saved · '
        '${widget.client.name} is now at '
        '${Money.format(newBalance.abs(), currency: ref.read(currencyProvider))}'
        '${newBalance > 0 ? ' outstanding' : newBalance < 0 ? ' in credit' : ' and settled'}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final projects = ref.watch(clientProjectsProvider(widget.client.id)).value
        ?? const <Project>[];
    final accent = _accent(context);

    final projected = widget.client.currentBalance + _delta;
    final hasAmount = (_parsedAmount ?? 0) > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, context.sheetBottomPadding()),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  title: _title,
                  client: widget.client,
                  accent: accent,
                  type: widget.type,
                ),
                const SizedBox(height: 20),

                const OfflineNotice(),

                AmountField(
                  controller: _amountController,
                  tint: accent,
                  onSubmitted: _save,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),

                QuickAmounts(
                  controller: _amountController,
                  amounts: _quickAmountsFor(currency),
                ),
                const SizedBox(height: 16),

                if (_isAdjustment) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.add_rounded, size: 16),
                        label: Text('Increase'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.remove_rounded, size: 16),
                        label: Text('Decrease'),
                      ),
                    ],
                    selected: {_increase},
                    onSelectionChanged: _saving
                        ? null
                        : (s) => setState(() => _increase = s.first),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _noteController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 140,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    hintText: _isPayment
                        ? 'UPI payment'
                        : 'Extra landing page',
                    counterText: '',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  ),
                  onFieldSubmitted: (_) => _save(),
                ),

                if (_isPayment) ...[
                  const SizedBox(height: 14),
                  _PaymentMethodPicker(
                    controller: _methodController,
                    enabled: !_saving,
                  ),
                ],

                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ProjectPicker(
                    projects: projects,
                    value: _projectId,
                    enabled: !_saving,
                    onChanged: (id) => setState(() => _projectId = id),
                  ),
                ],

                const SizedBox(height: 20),
                _BalancePreview(
                  before: widget.client.currentBalance,
                  after: projected,
                  delta: _delta,
                  active: hasAmount,
                  accent: accent,
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: (_saving || offline || !hasAmount) ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isPayment
                                ? Icons.south_west_rounded
                                : Icons.add_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : offline
                          ? 'Offline, cannot save'
                          : _isPayment
                          ? 'Record payment'
                          : 'Add charge',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Round figures worth one tap. Scaled to the currency so they stay sensible
  /// outside INR.
  List<int> _quickAmountsFor(Currency currency) {
    final unit = currency.minorPerMajor;
    if (currency.code == 'INR') {
      return [500, 1000, 2000, 5000, 10000, 25000].map((r) => r * unit).toList();
    }
    return [10, 25, 50, 100, 250, 500].map((r) => r * unit).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.client,
    required this.accent,
    required this.type,
  });

  final String title;
  final Client client;
  final Color accent;
  final TxType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            switch (type) {
              TxType.payment => Icons.south_west_rounded,
              TxType.adjustment => Icons.tune_rounded,
              _ => Icons.add_rounded,
            },
            color: accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleLarge),
              const SizedBox(height: 2),
              Text(
                client.companyName.isEmpty
                    ? client.name
                    : '${client.name} · ${client.companyName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Before → after, so the effect on the balance is visible before saving.
class _BalancePreview extends StatelessWidget {
  const _BalancePreview({
    required this.before,
    required this.after,
    required this.delta,
    required this.active,
    required this.accent,
  });

  final int before;
  final int after;
  final int delta;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current balance', style: context.text.labelSmall),
                const SizedBox(height: 4),
                MoneyText(
                  before,
                  absolute: true,
                  style: context.text.titleSmall,
                  color: context.scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: active ? accent : context.scheme.onSurfaceVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('After saving', style: context.text.labelSmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MoneyText(
                      active ? after : before,
                      absolute: true,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      color: active
                          ? context.scheme.onSurface
                          : context.scheme.onSurfaceVariant,
                      semanticsPrefix: 'Balance after saving',
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                BalanceStatusChip(balance: active ? after : before, dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodPicker extends StatelessWidget {
  const _PaymentMethodPicker({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Payment method',
            hintText: 'UPI, cash, bank transfer…',
            counterText: '',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PaymentMethods.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final method = PaymentMethods.all[i];
              return ActionChip(
                label: Text(method),
                onPressed: enabled ? () => controller.text = method : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.projects,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final List<Project> projects;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => !p.isArchived).toList();

    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Project',
        prefixIcon: Icon(Icons.folder_outlined, size: 20),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('General'),
        ),
        for (final project in active)
          DropdownMenuItem<String?>(
            value: project.id,
            child: Text(project.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
