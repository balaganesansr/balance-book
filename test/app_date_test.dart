import 'package:balance_book/core/utils/app_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Wednesday, so weekday maths is easy to reason about.
  final now = DateTime(2026, 8, 12, 14, 30);

  group('DateRange presets', () {
    test('today spans exactly one day', () {
      final range = DateRange.of(DatePreset.today, now: now);
      expect(range.start, DateTime(2026, 8, 12));
      expect(range.end, DateTime(2026, 8, 13));
    });

    test('this week starts on Monday and runs seven days', () {
      final range = DateRange.of(DatePreset.week, now: now);
      expect(range.start, DateTime(2026, 8, 10)); // Monday
      expect(range.end, DateTime(2026, 8, 17));
    });

    test('this month covers the calendar month', () {
      final range = DateRange.of(DatePreset.month, now: now);
      expect(range.start, DateTime(2026, 8));
      expect(range.end, DateTime(2026, 9));
    });

    test('last month rolls back correctly', () {
      final range = DateRange.of(DatePreset.lastMonth, now: now);
      expect(range.start, DateTime(2026, 7));
      expect(range.end, DateTime(2026, 8));
    });

    test('last month crosses a year boundary', () {
      final january = DateTime(2026, 1, 15);
      final range = DateRange.of(DatePreset.lastMonth, now: january);
      expect(range.start, DateTime(2025, 12));
      expect(range.end, DateTime(2026));
    });

    test('all time is unbounded', () {
      final range = DateRange.of(DatePreset.all, now: now);
      expect(range.isUnbounded, isTrue);
      expect(range.contains(DateTime(1999)), isTrue);
    });
  });

  group('DateRange.contains, half-open interval', () {
    test('includes the start instant and excludes the end instant', () {
      final range = DateRange.of(DatePreset.today, now: now);
      expect(range.contains(DateTime(2026, 8, 12)), isTrue);
      expect(range.contains(DateTime(2026, 8, 12, 23, 59, 59, 999)), isTrue);
      expect(range.contains(DateTime(2026, 8, 13)), isFalse);
      expect(range.contains(DateTime(2026, 8, 11, 23, 59)), isFalse);
    });

    test('a custom range covers the whole of its last day', () {
      final range = DateRange.custom(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 5),
      );
      expect(range.contains(DateTime(2026, 8, 5, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 6)), isFalse);
    });

    test('a custom range put in the wrong order is corrected', () {
      final range = DateRange.custom(
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 1),
      );
      expect(range.start, DateTime(2026, 8));
      expect(range.end, DateTime(2026, 8, 6));
    });
  });

  group('grouping headers', () {
    test('names today and yesterday', () {
      expect(AppDate.groupHeader(now, now: now), 'Today');
      expect(
        AppDate.groupHeader(DateTime(2026, 8, 11, 9), now: now),
        'Yesterday',
      );
    });

    test('uses the weekday inside the last week', () {
      expect(AppDate.groupHeader(DateTime(2026, 8, 9), now: now), 'Sunday');
    });

    test('falls back to a full date beyond a week', () {
      expect(
        AppDate.groupHeader(DateTime(2026, 7, 30), now: now),
        '30 Jul 2026',
      );
    });
  });

  group('relative time', () {
    test('describes recent moments', () {
      expect(
        AppDate.relative(now.subtract(const Duration(seconds: 20)), now: now),
        'Just now',
      );
      expect(
        AppDate.relative(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        AppDate.relative(now.subtract(const Duration(hours: 2)), now: now),
        '2h ago',
      );
    });

    test('describes earlier days', () {
      expect(
        AppDate.relative(DateTime(2026, 8, 11, 12), now: now),
        'Yesterday',
      );
      expect(AppDate.relative(DateTime(2026, 8, 9, 12), now: now), '3d ago');
      expect(AppDate.relative(DateTime(2026, 7, 12), now: now), '12 Jul');
      expect(AppDate.relative(DateTime(2025, 7, 12), now: now), '12 Jul 2025');
    });

    test('a clock-skewed future timestamp does not read as negative', () {
      expect(
        AppDate.relative(now.add(const Duration(minutes: 5)), now: now),
        'Just now',
      );
    });
  });
}
