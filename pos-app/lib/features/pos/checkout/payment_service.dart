// lib/features/pos/checkout/payment_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/business_date.dart';
import '../../accounting/models/journal_entry.dart';
import '../cart/sale_calculator.dart';

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
}

/// One requested cart line.
///
/// Price and tax status are loaded from the persisted product master to avoid
/// trusting mutable UI values during posting.
class PaymentLineInput {
  const PaymentLineInput({
    required this.productId,
    required this.quantity,
    this.itemDiscountAmount = 0,
  });

  final String productId;
  final int quantity;
  final int itemDiscountAmount;
}

/// Immutable checkout request.
class PaymentRequest {
  PaymentRequest({
    required this.transactionId,
    required this.method,
    required this.occurredAtUtc,
    required List<PaymentLineInput> lines,
    this.transactionDiscountAmount = 0,
    this.timezone = BusinessDate.timezoneId,
  }) : lines = List<PaymentLineInput>.unmodifiable(lines);

  final String transactionId;
  final PaymentMethod method;
  final DateTime occurredAtUtc;
  final List<PaymentLineInput> lines;
  final int transactionDiscountAmount;
  final String timezone;

  void validate() {
    if (transactionId.trim().isEmpty) {
      throw const PaymentValidationException('ID transaksi wajib diisi.');
    }
    if (lines.isEmpty) {
      throw const PaymentValidationException(
        'Keranjang tidak boleh kosong.',
      );
    }
    if (transactionDiscountAmount < 0) {
      throw const PaymentValidationException(
        'Diskon transaksi tidak boleh negatif.',
      );
    }
    if (timezone != BusinessDate.timezoneId) {
      throw const PaymentValidationException(
        'Zona waktu operasional harus Asia/Jakarta.',
      );
    }

    for (final line in lines) {
      if (line.productId.trim().isEmpty) {
        throw const PaymentValidationException('ID produk wajib diisi.');
      }
      if (line.quantity <= 0) {
        throw const PaymentValidationException(
          'Jumlah produk harus lebih dari nol.',
        );
      }
      if (line.itemDiscountAmount < 0) {
        throw const PaymentValidationException(
          'Diskon item tidak boleh negatif.',
        );
      }
    }
  }
}

/// Persisted result of one checkout.
class PaymentResult {
  const PaymentResult({
    required this.saleId,
    required this.journalEntry,
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableDpp,
    required this.exemptDpp,
    required this.ppnAmount,
    required this.grandTotal,
    required this.cogsAmount,
    required this.businessDate,
    required this.alreadyProcessed,
  });

  final String saleId;
  final JournalEntry journalEntry;
  final int grossAmount;
  final int discountAmount;
  final int taxableDpp;
  final int exemptDpp;
  final int ppnAmount;
  final int grandTotal;
  final int cogsAmount;
  final String businessDate;
  final bool alreadyProcessed;

  int get dpp => taxableDpp + exemptDpp;
}

/// Atomic sale persistence boundary.
///
/// Implementations must persist the sale, stock movement, journal, and outbox
/// event in one database transaction.
abstract class SaleRepository {
  Future<PaymentResult> processPayment(PaymentRequest request);
}

/// Checkout application service.
class PaymentService {
  const PaymentService({
    required SaleRepository repository,
  }) : _repository = repository;

  final SaleRepository _repository;

  Future<PaymentResult> process(PaymentRequest request) {
    request.validate();
    return _repository.processPayment(request);
  }

  static int calculatePpn(int taxableDpp) {
    return SaleCalculator.calculatePpn(taxableDpp);
  }
}

/// Riverpod wiring keeps state management outside the domain logic.
final paymentServiceProvider =
    Provider.family<PaymentService, SaleRepository>(
  (ref, repository) => PaymentService(repository: repository),
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
