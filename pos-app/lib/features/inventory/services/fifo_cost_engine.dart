// lib/features/inventory/services/fifo_cost_engine.dart

class FifoCostLayerCandidate {
  const FifoCostLayerCandidate({
    required this.id,
    required this.remainingQty,
    required this.unitCost,
    required this.acquiredAtUtc,
  });

  final String id;
  final int remainingQty;
  final int unitCost;
  final DateTime acquiredAtUtc;
}

class FifoCostConsumption {
  const FifoCostConsumption({
    required this.costLayerId,
    required this.quantity,
    required this.unitCost,
  });

  final String costLayerId;
  final int quantity;
  final int unitCost;

  int get totalCost => quantity * unitCost;
}

class FifoCostResult {
  FifoCostResult({
    required List<FifoCostConsumption> consumptions,
  }) : consumptions = List<FifoCostConsumption>.unmodifiable(consumptions);

  final List<FifoCostConsumption> consumptions;

  int get quantity => consumptions.fold<int>(
        0,
        (sum, consumption) => sum + consumption.quantity,
      );

  int get totalCost => consumptions.fold<int>(
        0,
        (sum, consumption) => sum + consumption.totalCost,
      );
}

/// Pure FIFO financial valuation policy for account 1-1040 / 5-5010.
class FifoCostEngine {
  const FifoCostEngine._();

  static FifoCostResult allocate({
    required List<FifoCostLayerCandidate> layers,
    required int requestedQuantity,
  }) {
    if (requestedQuantity <= 0) {
      throw const FifoCostValidationException(
        'Jumlah FIFO harus lebih dari nol.',
      );
    }

    final availableLayers = layers
        .where((layer) => layer.remainingQty > 0)
        .toList(growable: false)
      ..sort((left, right) {
        final acquiredCompare =
            left.acquiredAtUtc.compareTo(right.acquiredAtUtc);
        if (acquiredCompare != 0) {
          return acquiredCompare;
        }
        return left.id.compareTo(right.id);
      });

    final available = availableLayers.fold<int>(
      0,
      (sum, layer) => sum + layer.remainingQty,
    );
    if (available < requestedQuantity) {
      throw FifoCostDataIntegrityException(
        available: available,
        requested: requestedQuantity,
      );
    }

    var remaining = requestedQuantity;
    final consumptions = <FifoCostConsumption>[];
    for (final layer in availableLayers) {
      if (remaining == 0) {
        break;
      }
      final take = remaining < layer.remainingQty
          ? remaining
          : layer.remainingQty;
      consumptions.add(
        FifoCostConsumption(
          costLayerId: layer.id,
          quantity: take,
          unitCost: layer.unitCost,
        ),
      );
      remaining -= take;
    }

    return FifoCostResult(consumptions: consumptions);
  }
}

class FifoCostException implements Exception {
  const FifoCostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FifoCostValidationException extends FifoCostException {
  const FifoCostValidationException(super.message);
}

class FifoCostDataIntegrityException extends FifoCostException {
  FifoCostDataIntegrityException({
    required this.available,
    required this.requested,
  }) : super(
          'Layer FIFO tidak cukup. Tersedia $available, diminta $requested.',
        );

  final int available;
  final int requested;
}
