import 'package:balance_book/core/utils/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CSV encoding (RFC 4180)', () {
    test('leaves plain fields unquoted', () {
      expect(
        CsvExport.encode([
          ['Date', 'Type', 'Amount'],
        ]),
        'Date,Type,Amount\n',
      );
    });

    test('quotes fields containing a comma', () {
      final csv = CsvExport.encode([
        ['Extra work, phase 2', 'Charge'],
      ]);
      expect(csv, '"Extra work, phase 2",Charge\n');
    });

    test('doubles embedded quotes', () {
      final csv = CsvExport.encode([
        ['He said "urgent"'],
      ]);
      expect(csv, '"He said ""urgent"""\n');
    });

    test('quotes fields containing newlines', () {
      final csv = CsvExport.encode([
        ['Line one\nLine two'],
      ]);
      expect(csv, '"Line one\nLine two"\n');
    });

    test('a note that could break a spreadsheet stays one field', () {
      final csv = CsvExport.encode([
        ['2026-08-18', 'Charge', 'Landing page, "rush", v2', '2000.00'],
      ]);
      expect(
        csv,
        '2026-08-18,Charge,"Landing page, ""rush"", v2",2000.00\n',
      );
    });

    test('empty fields stay empty', () {
      expect(CsvExport.encode([['', 'x', '']]), ',x,\n');
    });
  });

  group('file names', () {
    test('slugifies the label and stamps the date', () {
      final name = CsvExport.fileNameFor(
        'Rahul Sharma-statement',
        now: DateTime(2026, 8, 18),
      );
      expect(name, 'Rahul-Sharma-statement-2026-08-18.csv');
    });

    test('strips characters that are illegal in a file name', () {
      final name = CsvExport.fileNameFor(
        r'A/B\C:D*E?F"G<H>I|J',
        now: DateTime(2026, 8, 18),
      );
      expect(name, 'ABCDEFGHIJ-2026-08-18.csv');
    });

    test('never produces an empty name', () {
      final name = CsvExport.fileNameFor('///', now: DateTime(2026, 8, 18));
      expect(name, 'export-2026-08-18.csv');
    });
  });
}
