import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

/// Large, keypad-friendly money input.
///
/// The field is the fastest part of the two flows that matter most (add a
/// charge, record a payment), so it is oversized, focused by default, and
/// accepts only what can be parsed into whole minor units.
class AmountField extends ConsumerStatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.autofocus = true,
    this.label,
    this.helperText,
    this.tint,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String? label;
  final String? helperText;
  final Color? tint;
  final String? Function(int? amount)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  ConsumerState<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends ConsumerState<AmountField> {
  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final accent = widget.tint ?? context.scheme.primary;

    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: currency.decimalDigits > 0,
      ),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        _SingleDecimalFormatter(maxDecimals: currency.decimalDigits),
      ],
      style: context.text.displaySmall
          ?.merge(AppTheme.tabularFigures)
          .copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        hintText: '0',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 6),
          child: Text(
            currency.symbol.trim(),
            style: context.text.headlineSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
      ),
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: (raw) {
        final text = raw?.trim() ?? '';
        if (text.isEmpty) return 'Enter an amount';
        final parsed = Money.tryParse(text, currency: currency);
        if (parsed == null) return 'That is not a valid amount';
        if (parsed <= 0) return 'Enter an amount greater than zero';
        return widget.validator?.call(parsed);
      },
    );
  }
}

/// Keeps input to a single decimal point with at most [maxDecimals] digits
/// after it, so the value always maps cleanly onto integer minor units.
class _SingleDecimalFormatter extends TextInputFormatter {
  const _SingleDecimalFormatter({required this.maxDecimals});

  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if (maxDecimals == 0 && text.contains('.')) return oldValue;

    final firstDot = text.indexOf('.');
    if (firstDot != -1) {
      // Reject a second decimal point.
      if (text.indexOf('.', firstDot + 1) != -1) return oldValue;
      final decimals = text.length - firstDot - 1;
      if (decimals > maxDecimals) return oldValue;
    }

    // Guard against pathological input long before it reaches arithmetic.
    if (text.replaceAll('.', '').length > 15) return oldValue;

    return newValue;
  }
}

/// Row of one-tap amounts that fill the field: the difference between four
/// taps and one when recording a common round figure.
class QuickAmounts extends ConsumerWidget {
  const QuickAmounts({
    super.key,
    required this.controller,
    required this.amounts,
    this.onPicked,
  });

  final TextEditingController controller;

  /// Minor-unit values.
  final List<int> amounts;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (amounts.isEmpty) return const SizedBox.shrink();
    final currency = ref.watch(currencyProvider);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: amounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final amount = amounts[index];
          return ActionChip(
            label: Text(Money.format(amount, currency: currency)),
            onPressed: () {
              controller.text = Money.toInput(amount, currency: currency);
              controller.selection = TextSelection.collapsed(
                offset: controller.text.length,
              );
              onPicked?.call();
            },
          );
        },
      ),
    );
  }
}
