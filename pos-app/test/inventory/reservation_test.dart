// test/inventory/reservation_test.dart

import 'package:berkahtigaputeri_pos/features/inventory/repositories/sqlite_reservation_repository.dart';
import 'package:berkahtigaputeri_pos/features/pos/checkout/payment_service.dart';
import 'package:berkahtigaputeri_pos/features/pos/checkout/sqlite_sale_repository.dart';
import 'package:berkahtigaputeri_pos/features/products/models/product.dart';
import 'package:berkahtigaputeri_pos/features/products/repositories/sqlite_product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  group('FEFO reservations', () {
    test('reservation locks FEFO batch and checkout consumes it atomically',
        () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final products = SqliteProductRepository(database);
      final reservations = SqliteInventoryReservationRepository(database);

      await products.upsert(
        const Product(
          id: 'P-RES',
          sku: 'SKU-RES',
          barcode: null,
          nameId: 'Obat Reservasi',
          price: 50000,
          ppnExempt: false,
          stockQty: 0,
          trackExpiry: true,
          minShelfLifeDays: 0,
        ),
      );

      await products.addInventoryLot(
        id: 'LOT-LATE',
        productId: 'P-RES',
        batchNo: 'B-LATE',
        expiryDate: DateTime(2027, 1, 31),
        quantity: 1,
        unitCost: 30000,
        acquiredAtUtc: DateTime.utc(2026, 8, 1),
      );
      await products.addInventoryLot(
        id: 'LOT-EARLY',
        productId: 'P-RES',
        batchNo: 'B-EARLY',
        expiryDate: DateTime(2026, 10, 31),
        quantity: 1,
        unitCost: 40000,
        acquiredAtUtc: DateTime.utc(2026, 9, 1),
      );

      final reservation = await reservations.reserve(
        id: 'RES-001',
        transactionId: 'TRX-RES-001',
        lines: const <InventoryReservationLineInput>[
          InventoryReservationLineInput(
            productId: 'P-RES',
            quantity: 1,
          ),
        ],
        createdAtUtc: DateTime.utc(2026, 9, 30, 3),
        expiresAtUtc: DateTime.utc(2026, 9, 30, 3, 10),
      );

      expect(reservation.status, 'active');
      expect(reservation.allocations.single.lotId, 'LOT-EARLY');

      final reservedLot = (await database.database.query(
        'inventory_lots',
        where: 'id = ?',
        whereArgs: <Object?>['LOT-EARLY'],
      ))
          .single;
      expect(reservedLot['on_hand_qty'], 1);
      expect(reservedLot['reserved_qty'], 1);

      final result = await PaymentService(
        repository: SqliteSaleRepository(database),
      ).process(
        PaymentRequest(
          transactionId: 'TRX-RES-001',
          reservationId: 'RES-001',
          method: PaymentMethod.cash,
          occurredAtUtc: DateTime.utc(2026, 9, 30, 3, 5),
          lines: const <PaymentLineInput>[
            PaymentLineInput(productId: 'P-RES', quantity: 1),
          ],
        ),
      );

      expect(result.cogsAmount, 30000);

      final committed = await reservations.findById('RES-001');
      expect(committed!.status, 'committed');

      final lots = await database.database.query(
        'inventory_lots',
        orderBy: 'id',
      );
      final byId = <String, Map<String, Object?>>{
        for (final row in lots) row['id']! as String: row,
      };
      expect(byId['LOT-EARLY']!['on_hand_qty'], 0);
      expect(byId['LOT-EARLY']!['reserved_qty'], 0);
      expect(byId['LOT-LATE']!['on_hand_qty'], 1);

      final saleAllocations = await database.database.query(
        'sale_lot_allocations',
      );
      expect(saleAllocations.single['lot_id'], 'LOT-EARLY');
    });

    test('expired reservation releases reserved quantity', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final products = SqliteProductRepository(database);
      final reservations = SqliteInventoryReservationRepository(database);

      await products.upsert(
        const Product(
          id: 'P-EXP-RES',
          sku: 'SKU-EXP-RES',
          barcode: null,
          nameId: 'Obat Reservasi Expired',
          price: 25000,
          ppnExempt: true,
          stockQty: 0,
          trackExpiry: true,
          minShelfLifeDays: 0,
        ),
      );
      await products.addInventoryLot(
        id: 'LOT-EXP-RES',
        productId: 'P-EXP-RES',
        batchNo: 'B-EXP-RES',
        expiryDate: DateTime(2027, 1, 31),
        quantity: 2,
        unitCost: 10000,
        acquiredAtUtc: DateTime.utc(2026, 9, 1),
      );

      await reservations.reserve(
        id: 'RES-EXP',
        transactionId: 'TRX-EXP',
        lines: const <InventoryReservationLineInput>[
          InventoryReservationLineInput(
            productId: 'P-EXP-RES',
            quantity: 1,
          ),
        ],
        createdAtUtc: DateTime.utc(2026, 9, 30, 3),
        expiresAtUtc: DateTime.utc(2026, 9, 30, 3, 5),
      );

      expect(
        await reservations.releaseExpired(DateTime.utc(2026, 9, 30, 3, 6)),
        1,
      );

      final released = await reservations.findById('RES-EXP');
      expect(released!.status, 'expired');

      final lot = (await database.database.query(
        'inventory_lots',
        where: 'id = ?',
        whereArgs: <Object?>['LOT-EXP-RES'],
      ))
          .single;
      expect(lot['on_hand_qty'], 2);
      expect(lot['reserved_qty'], 0);
    });
  });
}
