// lib/features/accounting/models/journal_entry.dart

import '../../../core/time/business_date.dart';

/// One debit or credit line in a journal entry.
///
/// Amounts are stored as integer Rupiah.
class JournalLine {
  const JournalLine({
    required this.accountCode,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final int debit;
  final int credit;

  bool get isDebit => debit > 0 && credit == 0;

  bool get isCredit => credit > 0 && debit == 0;

  bool sameAs(JournalLine other) {
    return accountCode == other.accountCode &&
        debit == other.debit &&
        credit == other.credit;
  }
}

/// Immutable double-entry accounting journal.
///
/// [date] is always treated as the UTC occurrence instant. [businessDate]
/// preserves the Indonesian operating date for reports.
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.transactionId,
    required List<JournalLine> lines,
    String? businessDate,
    this.timezone = BusinessDate.timezoneId,
  })  : businessDate =
            businessDate ?? BusinessDate.fromUtc(date.toUtc()),
        lines = List<JournalLine>.unmodifiable(lines);

  final String id;
  final DateTime date;
  final String transactionId;
  final String businessDate;
  final String timezone;
  final List<JournalLine> lines;

  int get totalDebit {
    return lines.fold<int>(0, (sum, line) => sum + line.debit);
  }

  int get totalCredit {
    return lines.fold<int>(0, (sum, line) => sum + line.credit);
  }

  bool get isBalanced => totalDebit == totalCredit;

  bool sameAs(JournalEntry other) {
    if (id != other.id ||
        date.toUtc() != other.date.toUtc() ||
        transactionId != other.transactionId ||
        businessDate != other.businessDate ||
        timezone != other.timezone ||
        lines.length != other.lines.length) {
      return false;
    }

    for (var index = 0; index < lines.length; index++) {
      if (!lines[index].sameAs(other.lines[index])) {
        return false;
      }
    }

    return true;
  }
}
