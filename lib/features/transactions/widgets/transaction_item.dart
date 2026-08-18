import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/money_text.dart';
import '../../../models/app_transaction.dart';
import '../../../models/enums.dart';

/// One row in a transaction list.
///
/// Reads at a glance: the signed amount on the right in the colour of its
/// direction, what it was for on the left, and the balance it left behind
/// underneath, so the history explains the current number line by line.
class TransactionItem extends StatelessWidget {
  const TransactionItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.clientName,
    this.projectName,
    this.showRunningBalance = true,
    this.dense = false,
  });

  final AppTransaction transaction;
  final VoidCallback? onTap;

  /// Shown instead of the note's leading position in the global activity feed.
  final String? clientName;

  final String? projectName;
  final bool showRunningBalance;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tx = transaction;
    final tint = colors.forDelta(tx.delta);
    final muted = tx.isReversed;

    final title = clientName ?? _titleFor(tx);
    final subtitle = clientName != null ? _titleFor(tx) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeGlyph(type: tx.type, delta: tx.delta, muted: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: muted
                            ? context.scheme.onSurfaceVariant
                            : context.scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _MetaLine(
                      transaction: tx,
                      projectName: projectName,
                      tint: tint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SignedAmount(transaction: tx, tint: tint, muted: muted),
                  if (showRunningBalance) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: context.text.labelSmall!.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      child: MoneyText(
                        tx.runningBalance,
                        absolute: true,
                        style: context.text.labelSmall,
                        color: context.scheme.onSurfaceVariant,
                        semanticsPrefix: 'Balance after',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleFor(AppTransaction tx) {
    if (tx.note.trim().isNotEmpty) return tx.note.trim();
    return tx.type.label;
  }
}

class _SignedAmount extends StatelessWidget {
  const _SignedAmount({
    required this.transaction,
    required this.tint,
    required this.muted,
  });

  final AppTransaction transaction;
  final Color tint;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = context.text.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      decoration: muted ? TextDecoration.lineThrough : null,
      decorationColor: context.scheme.onSurfaceVariant,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          transaction.signPrefix,
          style: style?.copyWith(
            color: muted ? context.scheme.onSurfaceVariant : tint,
          ),
        ),
        MoneyText(
          transaction.amount,
          absolute: true,
          style: style,
          color: muted ? context.scheme.onSurfaceVariant : tint,
          semanticsPrefix: transaction.delta >= 0 ? 'Charge of' : 'Payment of',
        ),
      ],
    );
  }
}

/// Type, time, project and status flags in one compact line.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.transaction,
    required this.projectName,
    required this.tint,
  });

  final AppTransaction transaction;
  final String? projectName;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final date = tx.createdAt;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Tag(label: tx.type.shortLabel, tint: tint),
        if (projectName != null && projectName!.isNotEmpty)
          _Tag(
            label: projectName!,
            tint: context.scheme.onSurfaceVariant,
            icon: Icons.folder_outlined,
          ),
        if (tx.isReversed)
          _Tag(
            label: 'Reversed',
            tint: context.scheme.error,
            icon: Icons.undo_rounded,
          ),
        if (tx.isPending)
          _Tag(
            label: 'Saving…',
            tint: context.scheme.onSurfaceVariant,
            icon: Icons.schedule_rounded,
          ),
        Text(
          date == null ? '' : AppDate.time(date),
          style: context.text.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tint, this.icon});

  final String label;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: tint),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon disc that says at a glance which way the money went.
class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({
    required this.type,
    required this.delta,
    required this.muted,
  });

  final TxType type;
  final int delta;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = muted ? context.scheme.onSurfaceVariant : colors.forDelta(delta);

    final icon = switch (type) {
      TxType.opening => Icons.flag_outlined,
      TxType.charge => Icons.add_rounded,
      TxType.payment => Icons.south_west_rounded,
      TxType.adjustment => Icons.tune_rounded,
      TxType.reversal => Icons.undo_rounded,
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 17, color: tint),
    );
  }
}
