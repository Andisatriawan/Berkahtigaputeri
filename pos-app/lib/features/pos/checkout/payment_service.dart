// lib/features/pos/checkout/payment_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounting/models/coa_account.dart';
import '../../accounting/models/journal_entry.dart';
import '../../accounting/services/journal_service.dart';

/// Payment methods supported by checkout.
enum PaymentMethod {
  cash,
  qris,
  transfer,
}

extension PaymentMethodX on PaymentMethod {
  String get labelId {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai';
      case PaymentMethod.qris:
        return 'QRIS';
      case PaymentMethod.transfer:
        return 'Transfer Bank';
    }
  }

  String get debitAccountCode {
    switch (this) {
      case PaymentMethod.cash:
        return CoaAccounts.cash.code;
      case PaymentMethod.qris:
        return CoaAccounts.qris.code;
      case PaymentMethod.transfer:
        return CoaAccounts.bankTransfer.code;
    }
  }
}

/// Immutable payment input.
///
/// All monetary values use integer Rupiah.
class PaymentRequest {
  const PaymentRequest({
    required this.transactionId,
    required this.grossAmount,
    required this.discountAmount,
    required this.cogsAmount,
    required this.method,
    required this.occurredAt,
    this.ppnExempt = false,
  });

  final String transactionId;
  final int grossAmount;
  final int discountAmount;
  final int cogsAmount;
  final PaymentMethod method;
  final DateTime occurredAt;
  final bool ppnExempt;

  int get dpp => grossAmount - discountAmount;

  int get ppnAmount => ppnExempt ? 0 : PaymentService.calculatePpn(dpp);

  int get grandTotal => dpp + ppnAmount;

  void validate() {
    if (transactionId.trim().isEmpty) {
      throw const PaymentValidationException('ID transaksi wajib diisi.');
    }
    if (grossAmount < 0) {
      throw const PaymentValidationException(
        'Nilai penjualan tidak boleh negatif.',
      );
    }
    if (discountAmount < 0) {
      throw const PaymentValidationException('Diskon tidak boleh negatif.');
    }
    if (discountAmount > grossAmount) {
      throw const PaymentValidationException(
        'Diskon tidak boleh melebihi nilai penjualan.',
      );
    }
    if (cogsAmount < 0) {
      throw const PaymentValidationException('HPP tidak boleh negatif.');
    }
  }
}

/// Result returned after a payment has been posted to the accounting journal.
class PaymentResult {
  const PaymentResult({
    required this.journalEntry,
    required this.dpp,
    required this.ppnAmount,
    required this.grandTotal,
    required this.alreadyProcessed,
  });

  final JournalEntry journalEntry;
  final int dpp;
  final int ppnAmount;
  final int grandTotal;
  final bool alreadyProcessed;
}

/// Creates POS payment journals using the M1 JournalService.
///
/// Account codes are sourced only from the approved COA model. JournalService
/// is the single posting boundary, so an unbalanced journal never mutates
/// accounting state and transactionId remains idempotent.
class PaymentService {
  const PaymentService({
    required JournalService journalService,
  }) : _journalService = journalService;

  static const int ppnRatePercent = 11;

  final JournalService _journalService;

  /// Calculates 11% PPN using integer Rupiah and half-up rounding.
  static int calculatePpn(int dpp) {
    if (dpp < 0) {
      throw const PaymentValidationException(
        'Dasar pengenaan PPN tidak boleh negatif.',
      );
    }
    return ((dpp * ppnRatePercent) + 50) ~/ 100;
  }

  PaymentResult process(PaymentRequest request) {
    request.validate();

    final transactionId = request.transactionId.trim();
    final existing = _journalService.findByTransactionId(transactionId);
    final entry = _buildEntry(
      request: request,
      transactionId: transactionId,
    );

    final posted = _journalService.post(entry);

    return PaymentResult(
      journalEntry: posted,
      dpp: request.dpp,
      ppnAmount: request.ppnAmount,
      grandTotal: request.grandTotal,
      alreadyProcessed: existing != null,
    );
  }

  JournalEntry _buildEntry({
    required PaymentRequest request,
    required String transactionId,
  }) {
    final lines = <JournalLine>[];

    if (request.grandTotal > 0) {
      lines.add(
        JournalLine(
          accountCode: request.method.debitAccountCode,
          debit: request.grandTotal,
          credit: 0,
        ),
      );
    }

    if (request.dpp > 0) {
      lines.add(
        JournalLine(
          accountCode: CoaAccounts.sales.code,
          debit: 0,
          credit: request.dpp,
        ),
      );
    }

    if (request.ppnAmount > 0) {
      lines.add(
        JournalLine(
          accountCode: CoaAccounts.ppnPayable.code,
          debit: 0,
          credit: request.ppnAmount,
        ),
      );
    }

    if (request.cogsAmount > 0) {
      lines
        ..add(
          JournalLine(
            accountCode: CoaAccounts.cogs.code,
            debit: request.cogsAmount,
            credit: 0,
          ),
        )
        ..add(
          JournalLine(
            accountCode: CoaAccounts.inventory.code,
            debit: 0,
            credit: request.cogsAmount,
          ),
        );
    }

    if (lines.isEmpty) {
      throw const PaymentValidationException(
        'Transaksi tidak menghasilkan jurnal.',
      );
    }

    return JournalEntry(
      id: _journalId(request, transactionId),
      date: request.occurredAt.toUtc(),
      transactionId: transactionId,
      lines: lines,
    );
  }

  String _journalId(PaymentRequest request, String transactionId) {
    return 'payment:$transactionId:'
        '${request.grossAmount}:'
        '${request.discountAmount}:'
        '${request.cogsAmount}:'
        '${request.method.name}:'
        '${request.ppnExempt ? 1 : 0}';
  }
}

/// Riverpod provider that reuses the M1 journal service.
final Provider<PaymentService> paymentServiceProvider =
    Provider<PaymentService>(
  (ref) => PaymentService(
    journalService: ref.read(journalServiceProvider.notifier),
  ),
);

class PaymentServiceException implements Exception {
  const PaymentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaymentValidationException extends PaymentServiceException {
  const PaymentValidationException(super.message);
}
