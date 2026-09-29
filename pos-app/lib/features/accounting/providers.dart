// lib/features/accounting/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/journal_repository.dart';
import 'services/journal_service.dart';

/// Riverpod wiring for the accounting application layer.
final journalServiceProvider =
    Provider.family<JournalService, JournalRepository>(
  (ref, repository) => JournalService(repository),
);
