// lib/features/inventory/repositories/sqlite_inventory_repository.dart

import 'package:sqflite/sqflite.dart';

import '../../../core/database/pos_database.dart';
import '../models/inventory_lot.dart';

/// Operational inventory controls that do not create accounting entries.
///
/// Holds and status changes only affect FEFO eligibility. Any future write-off
/// requiring a journal must pass through an explicitly approved COA mapping.
class SqliteInventoryRepository {
  SqliteInventoryRepository(this._database);

  final PosDatabase _database;

  Future<List<InventoryLot>> listLotsForProduct(String productId) async {
    final rows = await _database.database.query(
      'inventory_lots',
      where: 'product_id = ?',
      whereArgs: <Object?>[productId.trim()],
      orderBy: 'expiry_date, first_received_at_utc, id',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> placeHold({
    required String id,
    required String lotId,
    required String holdType,
    required String reason,
    required DateTime createdAtUtc,
  }) async {
    if (id.trim().isEmpty || lotId.trim().isEmpty) {
      throw const InventoryValidationException(
        'ID hold dan lot wajib diisi.',
      );
    }
    if (holdType.trim().isEmpty || reason.trim().isEmpty) {
      throw const InventoryValidationException(
        'Jenis dan alasan hold wajib diisi.',
      );
    }

    await _database.transaction((transaction) async {
      final lots = await transaction.query(
        'inventory_lots',
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[lotId.trim()],
        limit: 1,
      );
      if (lots.isEmpty) {
        throw InventoryLotMissingException(lotId.trim());
      }

      await transaction.insert(
        'lot_holds',
        <String, Object?>{
          'id': id.trim(),
          'lot_id': lotId.trim(),
          'hold_type': holdType.trim(),
          'reason': reason.trim(),
          'active': 1,
          'created_at_utc': createdAtUtc.toUtc().toIso8601String(),
          'released_at_utc': null,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<void> releaseHold({
    required String id,
    required DateTime releasedAtUtc,
  }) async {
    final changed = await _database.database.update(
      'lot_holds',
      <String, Object?>{
        'active': 0,
        'released_at_utc': releasedAtUtc.toUtc().toIso8601String(),
      },
      where: 'id = ? AND active = 1',
      whereArgs: <Object?>[id.trim()],
    );
    if (changed != 1) {
      throw InventoryHoldMissingException(id.trim());
    }
  }

  Future<void> setLotStatus({
    required String lotId,
    required InventoryLotStatus status,
  }) async {
    final changed = await _database.database.update(
      'inventory_lots',
      <String, Object?>{'status': status.name},
      where: 'id = ?',
      whereArgs: <Object?>[lotId.trim()],
    );
    if (changed != 1) {
      throw InventoryLotMissingException(lotId.trim());
    }
  }

  /// Marks already-expired dated lots as non-saleable. Checkout also performs
  /// its own date eligibility check, so correctness never depends on this job.
  Future<int> markExpiredLots(DateTime businessDate) {
    final date = _dateOnly(businessDate);
    return _database.database.rawUpdate(
      '''
      UPDATE inventory_lots
      SET status = 'expired'
      WHERE expiry_date IS NOT NULL
        AND expiry_date < ?
        AND status = 'saleable'
      ''',
      <Object?>[date],
    );
  }

  InventoryLot _fromRow(Map<String, Object?> row) {
    return InventoryLot(
      id: row['id']! as String,
      productId: row['product_id']! as String,
      batchNo: row['batch_no']! as String,
      expiryDate: row['expiry_date'] == null
          ? null
          : DateTime.parse(row['expiry_date']! as String),
      firstReceivedAtUtc:
          DateTime.parse(row['first_received_at_utc']! as String).toUtc(),
      onHandQty: row['on_hand_qty']! as int,
      reservedQty: row['reserved_qty']! as int,
      status: InventoryLotStatus.values.byName(row['status']! as String),
    );
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class InventoryRepositoryException implements Exception {
  const InventoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryValidationException extends InventoryRepositoryException {
  const InventoryValidationException(super.message);
}

class InventoryLotMissingException extends InventoryRepositoryException {
  InventoryLotMissingException(String lotId)
      : super('Lot "$lotId" tidak ditemukan.');
}

class InventoryHoldMissingException extends InventoryRepositoryException {
  InventoryHoldMissingException(String holdId)
      : super('Hold "$holdId" tidak aktif atau tidak ditemukan.');
}
