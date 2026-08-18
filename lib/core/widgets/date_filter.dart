import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_date.dart';

/// Horizontal period selector used by Activity, Reports and the dashboard.
///
/// Picking "Custom" opens the platform range picker; everything else resolves
/// to a concrete interval immediately.
class DateFilterBar extends StatelessWidget {
  const DateFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = const [
      DatePreset.today,
      DatePreset.week,
      DatePreset.month,
      DatePreset.lastMonth,
      DatePreset.all,
    ],
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final DateRange value;
  final ValueChanged<DateRange> onChanged;
  final List<DatePreset> presets;
  final EdgeInsetsGeometry padding;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: value.start != null && value.end != null
          ? DateTimeRange(
              start: value.start!,
              end: value.end!.subtract(const Duration(days: 1)),
            )
          : null,
      helpText: 'Select a period',
    );
    if (picked == null) return;
    onChanged(DateRange.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = value.preset == DatePreset.custom;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          for (final preset in presets) ...[
            ChoiceChip(
              label: Text(preset.shortLabel),
              selected: !isCustom && value.preset == preset,
              onSelected: (_) => onChanged(DateRange.of(preset)),
            ),
            const SizedBox(width: 8),
          ],
          ChoiceChip(
            avatar: Icon(
              Icons.date_range_rounded,
              size: 16,
              color: isCustom
                  ? context.scheme.onPrimaryContainer
                  : context.scheme.onSurfaceVariant,
            ),
            label: Text(isCustom ? value.label : 'Custom'),
            selected: isCustom,
            onSelected: (_) => _pickCustom(context),
          ),
        ],
      ),
    );
  }
}

/// Compact button that opens a menu of presets, for app bars where a
/// scrolling chip row would not fit.
class DateFilterButton extends StatelessWidget {
  const DateFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateRange value;
  final ValueChanged<DateRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DatePreset>(
      tooltip: 'Change period',
      position: PopupMenuPosition.under,
      onSelected: (preset) async {
        if (preset != DatePreset.custom) {
          onChanged(DateRange.of(preset));
          return;
        }
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 1, 12, 31),
          helpText: 'Select a period',
        );
        if (picked != null) {
          onChanged(DateRange.custom(picked.start, picked.end));
        }
      },
      itemBuilder: (context) => [
        for (final preset in DatePreset.values)
          PopupMenuItem(
            value: preset,
            child: Row(
              children: [
                if (value.preset == preset)
                  Icon(Icons.check_rounded, size: 18, color: context.scheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 10),
                Text(preset.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.colors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label,
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: context.scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
