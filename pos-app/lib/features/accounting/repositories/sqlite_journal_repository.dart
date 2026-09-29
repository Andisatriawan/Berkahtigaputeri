// lib/features/accounting/repositories/sqlite_journal_repository.dart

import 'package:sqflite/sqflite.dart';

import '../../../core/database/pos_database.dart';
import '../exceptions/accounting_exceptions.dart';
import '../models/journal_entry.dart';
import 'journal_repository.dart';

/// SQLite implementation of [JournalRepository].
class SqliteJournalRepository implements JournalRepository {
  SqliteJournalRepository(
    this._database, {
    DatabaseExecutor? executor,
  }) : _executor = executor;

  final PosDatabase _database;
  final DatabaseExecutor? _executor;

  DatabaseExecutor get _db => _executor ?? _database.database;

  @override
  Future<T> transaction<T>(
    Future<T> Function(JournalRepository repository) action,
  ) async {
    if (_executor != null) {
      return action(this);
    }

    return _database.transaction<T>(
      (transaction) => action(
        SqliteJournalRepository(
          _database,
          executor: transaction,
        ),
      ),
    );
  }

  @override
  Future<JournalEntry?> findByTransactionId(String transactionId) async {
    final journalRows = await _db.query(
      'journals',
      where: 'transaction_id = ?',
      whereArgs: <Object?>[transactionId],
      limit: 1,
    );

    if (journalRows.isEmpty) {
      return null;
    }

    return _hydrate(journalRows.first);
  }

  @override
  Future<JournalEntry> insert(JournalEntry entry) async {
    try {
      await _db.insert(
        'journals',
        <String, Object?>{
          'id': entry.id,
          'transaction_id': entry.transactionId,
          'occurred_at_utc': entry.date.toUtc().toIso8601String(),
          'business_date': entry.businessDate,
          'timezone': entry.timezone,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (var index = 0; index < entry.lines.length; index++) {
        final line = entry.lines[index];
        await _db.insert(
          'journal_lines',
          <String, Object?>{
            'journal_id': entry.id,
            'line_no': index,
            'account_code': line.accountCode,
            'debit': line.debit,
            'credit': line.credit,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      return entry;
    } on DatabaseException {
      final existing = await findByTransactionId(entry.transactionId);
      if (existing != null && existing.sameAs(entry)) {
        return existing;
      }
      if (existing != null) {
        throw DuplicateTransactionIdException(entry.transactionId);
      }
      rethrow;
    }
  }

  @override
  Future<List<JournalEntry>> listAll() async {
    final rows = await _db.query(
      'journals',
      orderBy: 'occurred_at_utc, id',
    );

    final entries = <JournalEntry>[];
    for (final row in rows) {
      entries.add(await _hydrate(row));
    }
    return List<JournalEntry>.unmodifiable(entries);
  }

  Future<JournalEntry> _hydrate(Map<String, Object?> journalRow) async {
    final journalId = journalRow['id']! as String;
    final lineRows = await _db.query(
      'journal_lines',
      where: 'journal_id = ?',
      whereArgs: <Object?>[journalId],
      orderBy: 'line_no',
    );

    return JournalEntry(
      id: journalId,
      date: DateTime.parse(
        journalRow['occurred_at_utc']! as String,
      ).toUtc(),
      transactionId: journalRow['transaction_id']! as String,
      businessDate: journalRow['business_date']! as String,
      timezone: journalRow['timezone']! as String,
      lines: lineRows
          .map(
            (row) => JournalLine(
              accountCode: row['account_code']! as String,
              debit: row['debit']! as int,
              credit: row['credit']! as int,
            ),
          )
          .toList(growable: false),
    );
  }
}
