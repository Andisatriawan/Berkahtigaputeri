// test/inventory/fefo_engine_test.dart

import 'package:berkahtigaputeri_pos/features/inventory/services/fefo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FefoEngine', () {
    test('orders by expiry, receipt time, then stable lot id', () {
      final result = FefoEngine.allocate(
        candidates: <FefoLotCandidate>[
          FefoLotCandidate(
            id: 'LOT-C',
            availableQty: 2,
            firstReceivedAtUtc: DateTime.utc(2026, 9, 2),
            expiryDate: DateTime(2026, 11, 1),
          ),
          FefoLotCandidate(
            id: 'LOT-B',
            availableQty: 2,
            firstReceivedAtUtc: DateTime.utc(2026, 9, 1),
            expiryDate: DateTime(2026, 10, 1),
          ),
          FefoLotCandidate(
            id: 'LOT-A',
            availableQty: 2,
            firstReceivedAtUtc: DateTime.utc(2026, 9, 1),
            expiryDate: DateTime(2026, 10, 1),
          ),
        ],
        requestedQuantity: 5,
        businessDate: DateTime(2026, 9, 30),
        trackExpiry: true,
        minShelfLifeDays: 0,
      );

      expect(
        result.allocations.map((allocation) => allocation.lotId),
        <String>['LOT-A', 'LOT-B', 'LOT-C'],
      );
      expect(
        result.allocations.map((allocation) => allocation.quantity),
        <int>[2, 2, 1],
      );
    });

    test('non-expiry product falls back to receipt FIFO', () {
      final result = FefoEngine.allocate(
        candidates: <FefoLotCandidate>[
          FefoLotCandidate(
            id: 'NEW',
            availableQty: 1,
            firstReceivedAtUtc: DateTime.utc(2026, 9, 2),
            expiryDate: null,
          ),
          FefoLotCandidate(
            id: 'OLD',
            availableQty: 1,
            firstReceivedAtUtc: DateTime.utc(2026, 9, 1),
            expiryDate: null,
          ),
        ],
        requestedQuantity: 1,
        businessDate: DateTime(2026, 9, 30),
        trackExpiry: false,
        minShelfLifeDays: 0,
      );

      expect(result.allocations.single.lotId, 'OLD');
    });
  });
}
