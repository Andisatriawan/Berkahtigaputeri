// lib/features/inventory/models/inventory_lot.dart

enum InventoryLotStatus {
  saleable,
  quarantine,
  damaged,
  expired,
  recall,
}

class InventoryLot {
  const InventoryLot({
    required this.id,
    required this.productId,
    required this.batchNo,
    required this.expiryDate,
    required this.firstReceivedAtUtc,
    required this.onHandQty,
    required this.reservedQty,
    required this.status,
  });

  final String id;
  final String productId;
  final String batchNo;
  final DateTime? expiryDate;
  final DateTime firstReceivedAtUtc;
  final int onHandQty;
  final int reservedQty;
  final InventoryLotStatus status;

  int get availableQty => onHandQty - reservedQty;
}
