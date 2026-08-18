import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../providers/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

/// Renders an integer minor-unit amount in the user's currency.
///
/// Always uses tabular figures, so a number that updates in place (a balance
/// ticking down as payments land) never shifts its digits sideways.
class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.color,
    this.signed = false,
    this.absolute = false,
    this.withSymbol = true,
    this.semanticsPrefix,
  });

  final int amount;
  final TextStyle? style;
  final Color? color;

  /// Show a leading `+` on positive amounts.
  final bool signed;

  /// Drop the sign entirely, for places where a nearby label already says which
  /// way the money moved.
  final bool absolute;

  final bool withSymbol;

  /// Read out before the amount by screen readers, e.g. "Balance".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final text = Money.format(
      amount,
      currency: currency,
      signed: signed,
      absolute: absolute,
      withSymbol: withSymbol,
    );

    final resolved = (style ?? DefaultTextStyle.of(context).style)
        .merge(AppTheme.tabularFigures)
        .copyWith(color: color);

    return Semantics(
      label: semanticsPrefix == null ? text : '$semanticsPrefix $text',
      excludeSemantics: true,
      child: Text(text, style: resolved, maxLines: 1),
    );
  }
}

/// The large balance figure at the top of a client profile.
class BalanceHeadline extends StatelessWidget {
  const BalanceHeadline({
    super.key,
    required this.balance,
    this.compact = false,
  });

  final int balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            balance,
            absolute: true,
            style: compact
                ? context.text.headlineMedium
                : context.text.displaySmall,
            color: context.scheme.onSurface,
            semanticsPrefix: 'Current balance',
          ),
        ),
        const SizedBox(height: 8),
        BalanceStatusChip(balance: balance),
      ],
    );
  }
}

/// "Outstanding" / "Settled" / "Credit" pill.
///
/// The wording is the point: a bare number cannot tell you whether ₹2,000 is
/// owed to you or by you, so the state is always spelled out next to it.
class BalanceStatusChip extends StatelessWidget {
  const BalanceStatusChip({
    super.key,
    required this.balance,
    this.dense = false,
  });

  final int balance;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final state = BalanceStateX.of(balance);
    final colors = context.colors;
    final foreground = colors.forState(state);

    final (label, icon) = switch (state) {
      BalanceState.outstanding => ('Outstanding', Icons.trending_up_rounded),
      BalanceState.settled => ('Settled', Icons.check_circle_outline_rounded),
      BalanceState.credit => ('Credit', Icons.savings_outlined),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceForState(state),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 14, color: foreground),
          SizedBox(width: dense ? 4 : 5),
          Text(
            label,
            style: (dense ? context.text.labelSmall : context.text.labelSmall)
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One-line balance summary used on list rows: the amount, coloured by state,
/// with the state word beneath it.
class BalanceCell extends StatelessWidget {
  const BalanceCell({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final state = BalanceStateX.of(balance);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(
          balance,
          absolute: true,
          style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          color: state == BalanceState.settled
              ? context.scheme.onSurfaceVariant
              : context.scheme.onSurface,
          semanticsPrefix: 'Balance',
        ),
        const SizedBox(height: 2),
        Text(
          switch (state) {
            BalanceState.outstanding => 'outstanding',
            BalanceState.settled => 'settled',
            BalanceState.credit => 'credit',
          },
          style: context.text.labelSmall?.copyWith(
            color: colors.forState(state),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
