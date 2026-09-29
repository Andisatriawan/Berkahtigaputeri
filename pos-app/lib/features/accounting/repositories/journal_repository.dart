// lib/features/accounting/repositories/journal_repository.dart

import '../models/journal_entry.dart';

/// Persistence boundary for append-only journals.
abstract class JournalRepository {
  Future<T> transaction<T>(
    Future<T> Function(JournalRepository repository) action,
  );

  Future<JournalEntry?> findByTransactionId(String transactionId);

  Future<JournalEntry> insert(JournalEntry entry);

  Future<List<JournalEntry>> listAll();
}
