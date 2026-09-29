// lib/features/inventory/repositories/sqlite_reservation_repository.dart

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/pos_database.dart';
import '../../../core/time/business_date.dart';
import '../../products/repositories/sqlite_product_repository.dart';
import '../services/fefo_engine.dart';

class InventoryReservationLineInput {
  const InventoryReservationLineInput({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;
}

class InventoryReservationAllocation {
  const InventoryReservationAllocation({
    required this.lineNo,
    required this.productId,
    required this.lotId,
    required this.quantity,
  });

  final int lineNo;
  final String productId;
  final String lotId;
  final int quantity;
}

class InventoryReservation {
  InventoryReservation({
    required this.id,
    required this.transactionId,
    required this.status,
    required this.expiresAtUtc,
    required List<InventoryReservationAllocation> allocations,
  }) : allocations =
            List<InventoryReservationAllocation>.unmodifiable(allocations);

  final String id;
  final String transactionId;
  final String status;
  final DateTime expiresAtUtc;
  final List<InventoryReservationAllocation> allocations;
}

/// Creates and releases pre-payment physical stock reservations.
///
/// Reserved quantities remain in `inventory_lots.on_hand_qty` and are excluded
/// from later FEFO allocations through `reserved_qty`. Checkout consumes both
/// fields atomically when `PaymentRequest.reservationId` is supplied.
class SqliteInventoryReservationRepository {
  SqliteInventoryReservationRepository(this._database);

  final PosDatabase _database;

  Future<InventoryReservation> reserve({
    required String id,
    required String transactionId,
    required List<InventoryReservationLineInput> lines,
    required DateTime createdAtUtc,
    required DateTime expiresAtUtc,
  }) async {
    final normalizedId = id.trim();
    final normalizedTransactionId = transactionId.trim();
    final created = createdAtUtc.toUtc();
    final expires = expiresAtUtc.toUtc();

    if (normalizedId.isEmpty || normalizedTransactionId.isEmpty) {
      throw const InventoryReservationValidationException(
        'ID reservasi dan transaksi wajib diisi.',
      );
    }
    if (lines.isEmpty) {
      throw const InventoryReservationValidationException(
        'Reservasi harus memiliki minimal satu baris.',
      );
    }
    if (!expires.isAfter(created)) {
      throw const InventoryReservationValidationException(
        'Waktu kedaluwarsa reservasi harus setelah waktu pembuatan.',
      );
    }
    for (final line in lines) {
      if (line.productId.trim().isEmpty || line.quantity <= 0) {
        throw const InventoryReservationValidationException(
          'Produk dan jumlah reservasi tidak valid.',
        );
      }
    }

    final fingerprint = _fingerprint(
      transactionId: normalizedTransactionId,
      lines: lines,
      expiresAtUtc: expires,
    );

    return _database.transaction<InventoryReservation>((transaction) async {
      final existing = await transaction.query(
        'inventory_reservations',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[normalizedTransactionId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        if (existing.single['request_fingerprint'] != fingerprint) {
          throw InventoryReservationConflictException(
            normalizedTransactionId,
          );
        }
        return _loadReservation(transaction, existing.single);
      }

      await transaction.insert(
        'inventory_reservations',
        <String, Object?>{
          'id': normalizedId,
          'transaction_id': normalizedTransactionId,
          'request_fingerprint': fingerprint,
          'status': 'active',
          'expires_at_utc': expires.toIso8601String(),
          'created_at_utc': created.toIso8601String(),
          'committed_at_utc': null,
          'released_at_utc': null,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final businessDate =
          DateTime.parse(BusinessDate.fromUtc(created));

      for (var lineNo = 0; lineNo < lines.length; lineNo++) {
        final input = lines[lineNo];
        final productId = input.productId.trim();
        final products = await transaction.query(
          'products',
          columns: <String>[
            'id',
            'name_id',
            'track_expiry',
            'min_shelf_life_days',
          ],
          where: 'id = ?',
          whereArgs: <Object?>[productId],
          limit: 1,
        );
        if (products.isEmpty) {
          throw ProductNotFoundException(productId);
        }
        final product = products.single;

        final lotRows = await transaction.rawQuery(
          '''
          SELECT l.*
          FROM inventory_lots l
          WHERE l.product_id = ?
            AND l.status = 'saleable'
            AND (l.on_hand_qty - l.reserved_qty) > 0
            AND NOT EXISTS (
              SELECT 1
              FROM lot_holds h
              WHERE h.lot_id = l.id
                AND h.active = 1
            )
          ''',
          <Object?>[productId],
        );

        final candidates = lotRows
            .map(
              (row) => FefoLotCandidate(
                id: row['id']! as String,
                availableQty: (row['on_hand_qty']! as int) -
                    (row['reserved_qty']! as int),
                firstReceivedAtUtc: DateTime.parse(
                  row['first_received_at_utc']! as String,
                ).toUtc(),
                expiryDate: row['expiry_date'] == null
                    ? null
                    : DateTime.parse(row['expiry_date']! as String),
              ),
            )
            .toList(growable: false);

        late final FefoAllocationResult result;
        try {
          result = FefoEngine.allocate(
            candidates: candidates,
            requestedQuantity: input.quantity,
            businessDate: businessDate,
            trackExpiry: (product['track_expiry']! as int) == 1,
            minShelfLifeDays:
                product['min_shelf_life_days']! as int,
          );
        } on FefoInsufficientStockException catch (error) {
          throw InventoryReservationInsufficientStockException(
            productName: product['name_id']! as String,
            available: error.available,
            requested: error.requested,
          );
        }

        for (var allocationNo = 0;
            allocationNo < result.allocations.length;
            allocationNo++) {
          final allocation = result.allocations[allocationNo];
          final changed = await transaction.rawUpdate(
            '''
            UPDATE inventory_lots
            SET reserved_qty = reserved_qty + ?
            WHERE id = ?
              AND status = 'saleable'
              AND (on_hand_qty - reserved_qty) >= ?
            ''',
            <Object?>[
              allocation.quantity,
              allocation.lotId,
              allocation.quantity,
            ],
          );
          if (changed != 1) {
            throw InventoryReservationDataIntegrityException(
              'Lot "${allocation.lotId}" berubah saat reservasi.',
            );
          }

          await transaction.insert(
            'inventory_reservation_lines',
            <String, Object?>{
              'reservation_id': normalizedId,
              'line_no': lineNo,
              'allocation_no': allocationNo,
              'product_id': productId,
              'lot_id': allocation.lotId,
              'quantity': allocation.quantity,
            },
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      final row = (await transaction.query(
        'inventory_reservations',
        where: 'id = ?',
        whereArgs: <Object?>[normalizedId],
        limit: 1,
      ))
          .single;
      return _loadReservation(transaction, row);
    });
  }

  Future<InventoryReservation?> findById(String id) async {
    final rows = await _database.database.query(
      'inventory_reservations',
      where: 'id = ?',
      whereArgs: <Object?>[id.trim()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _loadReservation(_database.database, rows.single);
  }

  Future<void> release({
    required String id,
    required DateTime releasedAtUtc,
  }) {
    return _database.transaction<void>((transaction) async {
      await _releaseWithinTransaction(
        transaction,
        id: id.trim(),
        releasedAtUtc: releasedAtUtc.toUtc(),
        status: 'released',
      );
    });
  }

  Future<int> releaseExpired(DateTime nowUtc) {
    final now = nowUtc.toUtc();
    return _database.transaction<int>((transaction) async {
      final rows = await transaction.query(
        'inventory_reservations',
        columns: <String>['id'],
        where: 'status = ? AND expires_at_utc <= ?',
        whereArgs: <Object?>['active', now.toIso8601String()],
      );

      for (final row in rows) {
        await _releaseWithinTransaction(
          transaction,
          id: row['id']! as String,
          releasedAtUtc: now,
          status: 'expired',
        );
      }
      return rows.length;
    });
  }

  Future<void> _releaseWithinTransaction(
    DatabaseExecutor executor, {
    required String id,
    required DateTime releasedAtUtc,
    required String status,
  }) async {
    final reservations = await executor.query(
      'inventory_reservations',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (reservations.isEmpty) {
      throw InventoryReservationNotFoundException(id);
    }
    if (reservations.single['status'] != 'active') {
      throw InventoryReservationStateException(
        'Reservasi "$id" tidak aktif.',
      );
    }

    final allocations = await executor.query(
      'inventory_reservation_lines',
      where: 'reservation_id = ?',
      whereArgs: <Object?>[id],
    );
    for (final allocation in allocations) {
      final quantity = allocation['quantity']! as int;
      final changed = await executor.rawUpdate(
        '''
        UPDATE inventory_lots
        SET reserved_qty = reserved_qty - ?
        WHERE id = ? AND reserved_qty >= ?
        ''',
        <Object?>[
          quantity,
          allocation['lot_id'],
          quantity,
        ],
      );
      if (changed != 1) {
        throw InventoryReservationDataIntegrityException(
          'Reserved quantity lot "${allocation['lot_id']}" tidak konsisten.',
        );
      }
    }

    await executor.update(
      'inventory_reservations',
      <String, Object?>{
        'status': status,
        'released_at_utc': releasedAtUtc.toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: <Object?>[id, 'active'],
    );
  }

  Future<InventoryReservation> _loadReservation(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final allocations = await executor.query(
      'inventory_reservation_lines',
      where: 'reservation_id = ?',
      whereArgs: <Object?>[row['id']],
      orderBy: 'line_no, allocation_no',
    );
    return InventoryReservation(
      id: row['id']! as String,
      transactionId: row['transaction_id']! as String,
      status: row['status']! as String,
      expiresAtUtc:
          DateTime.parse(row['expires_at_utc']! as String).toUtc(),
      allocations: allocations
          .map(
            (allocation) => InventoryReservationAllocation(
              lineNo: allocation['line_no']! as int,
              productId: allocation['product_id']! as String,
              lotId: allocation['lot_id']! as String,
              quantity: allocation['quantity']! as int,
            ),
          )
          .toList(growable: false),
    );
  }

  String _fingerprint({
    required String transactionId,
    required List<InventoryReservationLineInput> lines,
    required DateTime expiresAtUtc,
  }) {
    return jsonEncode(
      <String, Object?>{
        'transactionId': transactionId,
        'expiresAtUtc': expiresAtUtc.toIso8601String(),
        'lines': lines
            .map(
              (line) => <String, Object?>{
                'productId': line.productId.trim(),
                'quantity': line.quantity,
              },
            )
            .toList(growable: false),
      },
    );
  }
}

class InventoryReservationException implements Exception {
  const InventoryReservationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryReservationValidationException
    extends InventoryReservationException {
  const InventoryReservationValidationException(super.message);
}

class InventoryReservationConflictException
    extends InventoryReservationException {
  InventoryReservationConflictException(String transactionId)
      : super(
          'Transaction ID "$transactionId" sudah memiliki reservasi berbeda.',
        );
}

class InventoryReservationNotFoundException
    extends InventoryReservationException {
  InventoryReservationNotFoundException(String id)
      : super('Reservasi "$id" tidak ditemukan.');
}

class InventoryReservationStateException
    extends InventoryReservationException {
  const InventoryReservationStateException(super.message);
}

class InventoryReservationDataIntegrityException
    extends InventoryReservationException {
  const InventoryReservationDataIntegrityException(super.message);
}

class InventoryReservationInsufficientStockException
    extends InventoryReservationException {
  InventoryReservationInsufficientStockException({
    required String productName,
    required int available,
    required int requested,
  }) : super(
          'Stok FEFO "$productName" tidak cukup untuk reservasi. '
          'Tersedia $available, diminta $requested.',
        );
}
