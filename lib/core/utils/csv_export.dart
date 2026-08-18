import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/app_transaction.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/project.dart';
import 'app_date.dart';
import 'money.dart';

/// Builds CSV statements and writes them to a temporary file for sharing.
class CsvExport {
  const CsvExport._();

  /// A client's full statement, oldest first so the running balance reads
  /// top-to-bottom the way a ledger should.
  static String clientStatement({
    required Client client,
    required List<AppTransaction> transactions,
    required Currency currency,
    Map<String, Project> projects = const {},
  }) {
    final rows = <List<String>>[
      ['Date', 'Time', 'Type', 'Description', 'Project', 'Method', 'Amount', 'Balance'],
    ];

    final ordered = [...transactions]
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    for (final tx in ordered) {
      final date = tx.createdAt;
      rows.add([
        date == null ? '' : AppDate.iso(date),
        date == null ? '' : AppDate.time(date),
        tx.type.label,
        tx.note,
        projects[tx.projectId]?.name ?? '',
        tx.paymentMethod,
        // Signed so a spreadsheet can total the column directly.
        Money.formatPlain(tx.delta, currency: currency),
        Money.formatPlain(tx.runningBalance, currency: currency),
      ]);
    }

    rows.add(const ['', '', '', '', '', '', '', '']);
    rows.add([
      '',
      '',
      'Closing balance',
      client.name,
      '',
      '',
      '',
      Money.formatPlain(client.currentBalance, currency: currency),
    ]);

    return encode(rows);
  }

  /// One row per client: the "client performance" view as a spreadsheet.
  static String clientSummary({
    required List<Client> clients,
    required Currency currency,
  }) {
    final rows = <List<String>>[
      ['Client', 'Company', 'Phone', 'Email', 'Status', 'Charged', 'Paid', 'Balance'],
    ];

    for (final c in clients) {
      rows.add([
        c.name,
        c.companyName,
        c.phone,
        c.email,
        c.balanceState.label,
        Money.formatPlain(c.totalCharged, currency: currency),
        Money.formatPlain(c.totalPaid, currency: currency),
        Money.formatPlain(c.currentBalance, currency: currency),
      ]);
    }

    final total = clients.fold<int>(0, (sum, c) => sum + c.currentBalance);
    rows.add(const ['', '', '', '', '', '', '', '']);
    rows.add([
      'Total',
      '',
      '',
      '',
      '',
      '',
      '',
      Money.formatPlain(total, currency: currency),
    ]);

    return encode(rows);
  }

  /// RFC 4180 encoding: quote any field containing a comma, quote or newline,
  /// and double up embedded quotes.
  static String encode(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_field).join(','));
    }
    return buffer.toString();
  }

  static String _field(String value) {
    if (value.isEmpty) return '';
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Writes [csv] to a temp file and returns it, ready to hand to the share
  /// sheet. A UTF-8 BOM is included so Excel opens ₹ and other symbols
  /// correctly instead of showing mojibake.
  static Future<File> writeTempFile(String csv, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes([
      0xEF, 0xBB, 0xBF, // UTF-8 BOM
      ...utf8.encode(csv),
    ]);
    return file;
  }

  /// `Rahul-Sharma-statement-2026-08-18.csv`
  static String fileNameFor(String label, {DateTime? now}) {
    final stamp = AppDate.iso(now ?? DateTime.now());
    final slug = label
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    return '${slug.isEmpty ? 'export' : slug}-$stamp.csv';
  }
}
