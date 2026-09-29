// lib/features/accounting/services/journal_service.dart

import '../exceptions/accounting_exceptions.dart';
import '../models/coa_account.dart';
import '../models/journal_entry.dart';
import '../repositories/journal_repository.dart';


/// Validates and persists append-only double-entry journals.
///
/// Ordinary sales rules such as "PPN must be credited" belong to the sale
/// posting policy. This generic service also permits balanced reversal entries,
/// including a debit to 2-2010 when a sale is returned or corrected.
class JournalService {
  const JournalService(this._repository);

  final JournalRepository _repository;

  Future<JournalEntry> post(JournalEntry entry) {
    final normalized = _normalize(entry);
    validate(normalized);

    return _repository.transaction<JournalEntry>((repository) async {
      final existing = await repository.findByTransactionId(
        normalized.transactionId,
      );

      if (existing != null) {
        if (existing.sameAs(normalized)) {
          return existing;
        }
        throw DuplicateTransactionIdException(
          normalized.transactionId,
        );
      }

      return repository.insert(normalized);
    });
  }

  Future<JournalEntry?> findByTransactionId(String transactionId) {
    return _repository.findByTransactionId(transactionId.trim());
  }

  Future<List<JournalEntry>> listAll() => _repository.listAll();

  /// Validates accounting invariants without performing persistence.
  void validate(JournalEntry entry) {
    if (entry.id.trim().isEmpty) {
      throw const JournalValidationException('ID jurnal wajib diisi.');
    }

    if (entry.transactionId.trim().isEmpty) {
      throw const JournalValidationException('ID transaksi wajib diisi.');
    }

    if (entry.lines.isEmpty) {
      throw const JournalValidationException(
        'Jurnal harus memiliki minimal satu baris.',
      );
    }

    for (final line in entry.lines) {
      _validateLine(line);
    }

    if (!entry.isBalanced) {
      throw UnbalancedJournalException(
        totalDebit: entry.totalDebit,
        totalCredit: entry.totalCredit,
      );
    }
  }

  void _validateLine(JournalLine line) {
    if (line.accountCode.trim().isEmpty) {
      throw const JournalValidationException('Kode akun wajib diisi.');
    }

    if (CoaAccounts.findByCode(line.accountCode) == null) {
      throw UnknownAccountCodeException(line.accountCode);
    }

    if (line.debit < 0 || line.credit < 0) {
      throw const JournalValidationException(
        'Nilai debit dan kredit tidak boleh negatif.',
      );
    }

    if (line.debit == 0 && line.credit == 0) {
      throw const JournalValidationException(
        'Baris jurnal tidak boleh bernilai nol.',
      );
    }

    if (line.debit > 0 && line.credit > 0) {
      throw const JournalValidationException(
        'Satu baris jurnal tidak boleh memiliki debit dan kredit sekaligus.',
      );
    }
  }

  JournalEntry _normalize(JournalEntry entry) {
    return JournalEntry(
      id: entry.id.trim(),
      date: entry.date.toUtc(),
      transactionId: entry.transactionId.trim(),
      businessDate: entry.businessDate,
      timezone: entry.timezone,
      lines: entry.lines,
    );
  }
}
