// test/pos/checkout/payment_service_test.dart

import 'package:berkahtigaputeri_pos/features/accounting/services/journal_service.dart';
import 'package:berkahtigaputeri_pos/features/pos/checkout/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentService', () {
    test('menghitung PPN 11% setelah diskon dan jurnal tetap seimbang', () {
      final journalService = JournalService();
      final service = PaymentService(journalService: journalService);

      final result = service.process(
        PaymentRequest(
          transactionId: 'TRX-PAY-001',
          grossAmount: 100000,
          discountAmount: 10000,
          cogsAmount: 60000,
          method: PaymentMethod.cash,
          occurredAt: DateTime.utc(2026, 9, 29, 10),
        ),
      );

      expect(result.dpp, 90000);
      expect(result.ppnAmount, 9900);
      expect(result.grandTotal, 99900);
      expect(result.journalEntry.totalDebit, 159900);
      expect(result.journalEntry.totalCredit, 159900);
      expect(result.journalEntry.isBalanced, isTrue);

      final cash = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '1-1010',
      );
      final sales = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '4-4010',
      );
      final ppn = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '2-2010',
      );
      final cogs = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '5-5010',
      );
      final inventory = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '1-1040',
      );

      expect(cash.debit, 99900);
      expect(sales.credit, 90000);
      expect(ppn.credit, 9900);
      expect(cogs.debit, 60000);
      expect(inventory.credit, 60000);
    });

    test('produk bebas PPN tidak memposting akun 2-2010', () {
      final journalService = JournalService();
      final service = PaymentService(journalService: journalService);

      final result = service.process(
        PaymentRequest(
          transactionId: 'TRX-PAY-002',
          grossAmount: 50000,
          discountAmount: 5000,
          cogsAmount: 25000,
          method: PaymentMethod.qris,
          occurredAt: DateTime.utc(2026, 9, 29, 11),
          ppnExempt: true,
        ),
      );

      expect(result.dpp, 45000);
      expect(result.ppnAmount, 0);
      expect(result.grandTotal, 45000);
      expect(
        result.journalEntry.lines.where(
          (line) => line.accountCode == '2-2010',
        ),
        isEmpty,
      );

      final qris = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '1-1020',
      );
      expect(qris.debit, 45000);
      expect(result.journalEntry.isBalanced, isTrue);
    });

    test('transfer bank menggunakan akun 1-1030', () {
      final service = PaymentService(journalService: JournalService());

      final result = service.process(
        PaymentRequest(
          transactionId: 'TRX-PAY-003',
          grossAmount: 10000,
          discountAmount: 0,
          cogsAmount: 4000,
          method: PaymentMethod.transfer,
          occurredAt: DateTime.utc(2026, 9, 29, 12),
        ),
      );

      final transfer = result.journalEntry.lines.singleWhere(
        (line) => line.accountCode == '1-1030',
      );

      expect(transfer.debit, 11100);
      expect(result.journalEntry.isBalanced, isTrue);
    });

    test('transactionId identik tidak diposting dua kali', () {
      final journalService = JournalService();
      final service = PaymentService(journalService: journalService);
      final request = PaymentRequest(
        transactionId: 'TRX-PAY-004',
        grossAmount: 25000,
        discountAmount: 5000,
        cogsAmount: 12000,
        method: PaymentMethod.cash,
        occurredAt: DateTime.utc(2026, 9, 29, 13),
      );

      final first = service.process(request);
      final second = service.process(request);

      expect(first.alreadyProcessed, isFalse);
      expect(second.alreadyProcessed, isTrue);
      expect(journalService.state, hasLength(1));
      expect(
        second.journalEntry.transactionId,
        first.journalEntry.transactionId,
      );
    });

    test('transactionId sama dengan isi berbeda ditolak tanpa double post', () {
      final journalService = JournalService();
      final service = PaymentService(journalService: journalService);

      service.process(
        PaymentRequest(
          transactionId: 'TRX-PAY-005',
          grossAmount: 20000,
          discountAmount: 0,
          cogsAmount: 10000,
          method: PaymentMethod.cash,
          occurredAt: DateTime.utc(2026, 9, 29, 14),
        ),
      );

      expect(
        () => service.process(
          PaymentRequest(
            transactionId: 'TRX-PAY-005',
            grossAmount: 30000,
            discountAmount: 0,
            cogsAmount: 15000,
            method: PaymentMethod.cash,
            occurredAt: DateTime.utc(2026, 9, 29, 14),
          ),
        ),
        throwsA(isA<DuplicateTransactionIdException>()),
      );
      expect(journalService.state, hasLength(1));
    });

    test('validasi gagal tidak mengubah jurnal', () {
      final journalService = JournalService();
      final service = PaymentService(journalService: journalService);

      expect(
        () => service.process(
          PaymentRequest(
            transactionId: 'TRX-PAY-006',
            grossAmount: 10000,
            discountAmount: 11000,
            cogsAmount: 5000,
            method: PaymentMethod.cash,
            occurredAt: DateTime.utc(2026, 9, 29, 15),
          ),
        ),
        throwsA(isA<PaymentValidationException>()),
      );
      expect(journalService.state, isEmpty);
    });

    test('pembulatan PPN memakai integer Rupiah tanpa floating point', () {
      expect(PaymentService.calculatePpn(4), 0);
      expect(PaymentService.calculatePpn(5), 1);
      expect(PaymentService.calculatePpn(999), 110);
      expect(PaymentService.calculatePpn(1000), 110);
    });
  });
}
