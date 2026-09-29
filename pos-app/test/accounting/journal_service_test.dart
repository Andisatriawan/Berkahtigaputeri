// test/accounting/journal_service_test.dart

import 'package:berkahtigaputeri_pos/features/accounting/models/journal_entry.dart';
import 'package:berkahtigaputeri_pos/features/accounting/repositories/sqlite_journal_repository.dart';
import 'package:berkahtigaputeri_pos/features/accounting/services/journal_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  group('JournalService', () {
    test('memposting dan membaca kembali jurnal seimbang', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final service = JournalService(
        SqliteJournalRepository(database),
      );

      final entry = JournalEntry(
        id: 'J-001',
        date: DateTime.utc(2026, 9, 29, 10),
        transactionId: 'TRX-001',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 111000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 100000),
          JournalLine(accountCode: '2-2010', debit: 0, credit: 11000),
          JournalLine(accountCode: '5-5010', debit: 60000, credit: 0),
          JournalLine(accountCode: '1-1040', debit: 0, credit: 60000),
        ],
      );

      final posted = await service.post(entry);
      final stored = await service.findByTransactionId('TRX-001');

      expect(posted.totalDebit, 171000);
      expect(posted.totalCredit, 171000);
      expect(posted.isBalanced, isTrue);
      expect(stored, isNotNull);
      expect(stored!.sameAs(posted), isTrue);
      expect(await service.listAll(), hasLength(1));
    });

    test('menolak jurnal tidak seimbang dan tidak menyimpan apa pun', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final service = JournalService(
        SqliteJournalRepository(database),
      );

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
      expect(await service.listAll(), isEmpty);
    });

    test('transactionId identik tetap idempoten di repository', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final firstService = JournalService(
        SqliteJournalRepository(database),
      );

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

      final first = await firstService.post(entry);

      final restartedService = JournalService(
        SqliteJournalRepository(database),
      );
      final second = await restartedService.post(entry);

      expect(second.sameAs(first), isTrue);
      expect(await restartedService.listAll(), hasLength(1));
    });

    test('transactionId sama dengan isi berbeda ditolak', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final service = JournalService(
        SqliteJournalRepository(database),
      );

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

      await service.post(first);

      await expectLater(
        service.post(conflicting),
        throwsA(isA<DuplicateTransactionIdException>()),
      );
      expect(await service.listAll(), hasLength(1));
    });

    test('generic journal mengizinkan reversal debit ke 2-2010', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final service = JournalService(
        SqliteJournalRepository(database),
      );

      final reversal = JournalEntry(
        id: 'J-REV-001',
        date: DateTime.utc(2026, 9, 29, 15),
        transactionId: 'REV-001',
        lines: const <JournalLine>[
          JournalLine(accountCode: '2-2010', debit: 11000, credit: 0),
          JournalLine(accountCode: '1-1010', debit: 0, credit: 11000),
        ],
      );

      final posted = await service.post(reversal);

      expect(posted.isBalanced, isTrue);
      expect(await service.listAll(), hasLength(1));
    });

    test('businessDate mengikuti WIB dan bukan tanggal UTC', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final service = JournalService(
        SqliteJournalRepository(database),
      );

      final entry = JournalEntry(
        id: 'J-DATE-001',
        date: DateTime.utc(2026, 9, 29, 17, 30),
        transactionId: 'TRX-DATE-001',
        lines: const <JournalLine>[
          JournalLine(accountCode: '1-1010', debit: 1000, credit: 0),
          JournalLine(accountCode: '4-4010', debit: 0, credit: 1000),
        ],
      );

      final posted = await service.post(entry);

      expect(posted.businessDate, '2026-09-30');
      expect(posted.timezone, 'Asia/Jakarta');
    });
  });
}
