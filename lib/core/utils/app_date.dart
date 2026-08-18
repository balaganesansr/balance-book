import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Named period used by the date filter across Activity, Reports and Home.
enum DatePreset { all, today, week, month, lastMonth, custom }

extension DatePresetLabel on DatePreset {
  String get label => switch (this) {
    DatePreset.all => 'All time',
    DatePreset.today => 'Today',
    DatePreset.week => 'This week',
    DatePreset.month => 'This month',
    DatePreset.lastMonth => 'Last month',
    DatePreset.custom => 'Custom',
  };

  String get shortLabel => switch (this) {
    DatePreset.all => 'All',
    DatePreset.today => 'Today',
    DatePreset.week => 'Week',
    DatePreset.month => 'Month',
    DatePreset.lastMonth => 'Last month',
    DatePreset.custom => 'Custom',
  };
}

/// A half-open interval `[start, end)`. `null` on either side means unbounded.
///
/// Half-open avoids the classic off-by-one where a transaction recorded at
/// 23:59:59.500 on the last day of a range is silently dropped.
@immutable
class DateRange {
  const DateRange({required this.preset, this.start, this.end});

  final DatePreset preset;
  final DateTime? start;
  final DateTime? end;

  static const all = DateRange(preset: DatePreset.all);

  bool get isUnbounded => start == null && end == null;

  bool contains(DateTime when) {
    if (start != null && when.isBefore(start!)) return false;
    if (end != null && !when.isBefore(end!)) return false;
    return true;
  }

  /// Builds the concrete interval for a preset, relative to [now].
  factory DateRange.of(DatePreset preset, {DateTime? now}) {
    final today = AppDate.startOfDay(now ?? DateTime.now());
    switch (preset) {
      case DatePreset.all:
        return all;
      case DatePreset.today:
        return DateRange(
          preset: preset,
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case DatePreset.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(
          preset: preset,
          start: monday,
          end: monday.add(const Duration(days: 7)),
        );
      case DatePreset.month:
        final first = DateTime(today.year, today.month);
        return DateRange(
          preset: preset,
          start: first,
          end: DateTime(today.year, today.month + 1),
        );
      case DatePreset.lastMonth:
        return DateRange(
          preset: preset,
          start: DateTime(today.year, today.month - 1),
          end: DateTime(today.year, today.month),
        );
      case DatePreset.custom:
        return all;
    }
  }

  /// A custom range from two picked days, inclusive of the whole [last] day.
  factory DateRange.custom(DateTime first, DateTime last) {
    final a = AppDate.startOfDay(first);
    final b = AppDate.startOfDay(last);
    final (from, to) = a.isAfter(b) ? (b, a) : (a, b);
    return DateRange(
      preset: DatePreset.custom,
      start: from,
      end: to.add(const Duration(days: 1)),
    );
  }

  String get label {
    if (preset != DatePreset.custom) return preset.label;
    if (start == null || end == null) return 'Custom';
    final lastDay = end!.subtract(const Duration(days: 1));
    if (AppDate.isSameDay(start!, lastDay)) return AppDate.day(start!);
    return '${AppDate.dayShort(start!)} – ${AppDate.dayShort(lastDay)}';
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.preset == preset &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}

/// Date formatting helpers. All formats are built once and reused. Building a
/// [DateFormat] inside a list item builder is measurably slow.
class AppDate {
  const AppDate._();

  static final _time = DateFormat('h:mm a');
  static final _day = DateFormat('d MMM yyyy');
  static final _dayShort = DateFormat('d MMM');
  static final _weekday = DateFormat('EEEE');
  static final _dayWithWeekday = DateFormat('EEEE, d MMM yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');
  static final _isoTime = DateFormat('yyyy-MM-dd HH:mm');

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String time(DateTime d) => _time.format(d);
  static String day(DateTime d) => _day.format(d);
  static String dayShort(DateTime d) => _dayShort.format(d);
  static String dayWithWeekday(DateTime d) => _dayWithWeekday.format(d);
  static String iso(DateTime d) => _iso.format(d);
  static String isoTime(DateTime d) => _isoTime.format(d);

  /// Header used to group a transaction list: `Today`, `Yesterday`,
  /// `Wednesday` (within the last week) or `12 Aug 2026`.
  static String groupHeader(DateTime d, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final that = startOfDay(d);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return _weekday.format(d);
    return _day.format(d);
  }

  /// Compact relative time for activity rows: `Just now`, `2h ago`,
  /// `Yesterday`, `12 Aug`.
  static String relative(DateTime d, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(d);

    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && isSameDay(d, current)) {
      return '${diff.inHours}h ago';
    }

    final days = startOfDay(current).difference(startOfDay(d)).inDays;
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    if (d.year == current.year) return _dayShort.format(d);
    return _day.format(d);
  }

  /// Long form used on detail screens: `Wednesday, 12 Aug 2026 at 10:42 AM`.
  static String full(DateTime d) => '${_dayWithWeekday.format(d)} at ${_time.format(d)}';
}
