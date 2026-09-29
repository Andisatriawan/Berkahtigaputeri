// lib/features/accounting/services/journal_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coa_account.dart';
import '../models/journal_entry.dart';

/// Stores posted journals in memory for the current application session.
///
/// A persistent repository can later wrap this service without changing the
/// posting invariants enforced here.
class JournalService extends StateNotifier<List<JournalEntry>> {
  JournalService() : super(const <JournalEntry>[]);

  static const String ppnPayableAccountCode = '2-2010';

  /// Posts a balanced journal exactly once per transactionId.
  ///
  /// Reposting an identical entry is idempotent and returns the previously
  /// posted entry. Reusing the same transactionId with different content is
  /// rejected.
  JournalEntry post(JournalEntry entry) {
    _validate(entry);

    final normalizedTransactionId = entry.transactionId.trim();
    final existing = _findByTransactionId(normalizedTransactionId);

    if (existing != null) {
      if (_sameTransaction(existing, entry, normalizedTransactionId)) {
        return existing;
      }
      throw DuplicateTransactionIdException(normalizedTransactionId);
    }

    final normalizedEntry = JournalEntry(
      id: entry.id.trim(),
      date: entry.date.toUtc(),
      transactionId: normalizedTransactionId,
      lines: entry.lines,
    );

    // State changes only after all validation passes.
    state = List<JournalEntry>.unmodifiable(
      <JournalEntry>[...state, normalizedEntry],
    );

    return normalizedEntry;
  }

  JournalEntry? findByTransactionId(String transactionId) {
    return _findByTransactionId(transactionId.trim());
  }

  void _validate(JournalEntry entry) {
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

    if (line.accountCode == ppnPayableAccountCode &&
        !(line.credit > 0 && line.debit == 0)) {
      throw const PpnPostingException(
        'PPN 11% wajib dikreditkan ke akun 2-2010.',
      );
    }
  }

  JournalEntry? _findByTransactionId(String transactionId) {
    for (final entry in state) {
      if (entry.transactionId == transactionId) {
        return entry;
      }
    }
    return null;
  }

  bool _sameTransaction(
    JournalEntry existing,
    JournalEntry candidate,
    String normalizedTransactionId,
  ) {
    final normalizedCandidate = JournalEntry(
      id: candidate.id.trim(),
      date: candidate.date.toUtc(),
      transactionId: normalizedTransactionId,
      lines: candidate.lines,
    );
    return existing.sameAs(normalizedCandidate);
  }
}

/// Riverpod state for all journals posted during the current session.
final StateNotifierProvider<JournalService, List<JournalEntry>>
    journalServiceProvider =
    StateNotifierProvider<JournalService, List<JournalEntry>>(
  (ref) => JournalService(),
);

class JournalServiceException implements Exception {
  const JournalServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JournalValidationException extends JournalServiceException {
  const JournalValidationException(super.message);
}

class PpnPostingException extends JournalServiceException {
  const PpnPostingException(super.message);
}

class UnknownAccountCodeException extends JournalServiceException {
  UnknownAccountCodeException(String accountCode)
      : super(
          'Kode akun "$accountCode" tidak terdaftar pada COA M1.',
        );
}

class DuplicateTransactionIdException extends JournalServiceException {
  DuplicateTransactionIdException(String transactionId)
      : super(
          'ID transaksi "$transactionId" sudah digunakan oleh jurnal lain.',
        );
}

class UnbalancedJournalException extends JournalServiceException {
  UnbalancedJournalException({
    required this.totalDebit,
    required this.totalCredit,
  }) : super(
          'Jurnal tidak seimbang: debit Rp$totalDebit, kredit Rp$totalCredit.',
        );

  final int totalDebit;
  final int totalCredit;
}
