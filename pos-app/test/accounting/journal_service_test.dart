// test/accounting/journal_service_test.dart

import 'package:berkahtigaputeri_pos/features/accounting/models/journal_entry.dart';
import 'package:berkahtigaputeri_pos/features/accounting/services/journal_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalService', () {
    test('memposting jurnal seimbang', () {
      final service = JournalService();
      final entry = JournalEntry(
        id: 'J-001',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-001',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 111000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 100000),
          JournalLine(accountCode: '2-2010', debit: 0, credit: 11000),
          JournalLine(accountCode: '5-5010', debit: 60000, credit: 0),
          JournalLine(accountCode: '1-1040', debit: 0, credit: 60000),
        ],
      );

      final posted = service.post(entry);

      expect(posted.totalDebit, 171000);
      expect(posted.totalCredit, 171000);
      expect(service.state, hasLength(1));
    });

    test('menolak jurnal tidak seimbang tanpa mengubah state', () {
      final service = JournalService();
      final entry = JournalEntry(
        id: 'J-002',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-002',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 100000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 90000),
        ],
      );

      expect(
        () => service.post(entry),
        throwsA(isA<UnbalancedJournalException>()),
      );
      expect(service.state, isEmpty);
    });

    test('posting identik dengan transactionId sama bersifat idempoten', () {
      final service = JournalService();
      final entry = JournalEntry(
        id: 'J-003',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-003',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 111000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 100000),
          JournalLine(accountCode: '2-2010', debit: 0, credit: 11000),
        ],
      );

      final first = service.post(entry);
      final second = service.post(entry);

      expect(identical(first, second), isTrue);
      expect(service.state, hasLength(1));
    });

    test('menolak transactionId sama dengan isi berbeda', () {
      final service = JournalService();
      final first = JournalEntry(
        id: 'J-004',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-004',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 111000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 100000),
          JournalLine(accountCode: '2-2010', debit: 0, credit: 11000),
        ],
      );
      final conflicting = JournalEntry(
        id: 'J-005',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-004',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 222000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 200000),
          JournalLine(accountCode: '2-2010', debit: 0, credit: 22000),
        ],
      );

      service.post(first);

      expect(
        () => service.post(conflicting),
        throwsA(isA<DuplicateTransactionIdException>()),
      );
      expect(service.state, hasLength(1));
    });

    test('PPN 11 persen hanya boleh kredit ke 2-2010', () {
      final service = JournalService();
      final entry = JournalEntry(
        id: 'J-006',
        date: DateTime.utc(2026, 9, 29),
        transactionId: 'TRX-006',
        lines: const <JournalLine>[
          JournalLine(accountCode: '2-2010', debit: 11000, credit: 0),
          JournalLine(accountCode: '1-1010', debit: 0, credit: 11000),
        ],
      );

      expect(
        () => service.post(entry),
        throwsA(isA<PpnPostingException>()),
      );
      expect(service.state, isEmpty);
    });
  });
}
