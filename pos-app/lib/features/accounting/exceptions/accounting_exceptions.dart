// lib/features/accounting/exceptions/accounting_exceptions.dart

/// Base exception for accounting-domain failures.
class AccountingException implements Exception {
  const AccountingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JournalValidationException extends AccountingException {
  const JournalValidationException(super.message);
}

class UnknownAccountCodeException extends AccountingException {
  UnknownAccountCodeException(String accountCode)
      : super('Kode akun "$accountCode" tidak terdaftar pada COA.');
}

class DuplicateTransactionIdException extends AccountingException {
  DuplicateTransactionIdException(String transactionId)
      : super(
          'ID transaksi "$transactionId" sudah digunakan oleh transaksi lain.',
        );
}

class UnbalancedJournalException extends AccountingException {
  UnbalancedJournalException({
    required this.totalDebit,
    required this.totalCredit,
  }) : super(
          'Jurnal tidak seimbang: debit Rp$totalDebit, kredit Rp$totalCredit.',
        );

  final int totalDebit;
  final int totalCredit;
}
