// lib/features/products/models/product.dart

/// Product master used by the POS and inventory modules.
///
/// Monetary values use integer Rupiah.
class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.nameId,
    required this.price,
    required this.ppnExempt,
    required this.stockQty,
    this.trackExpiry = false,
    this.minShelfLifeDays = 0,
  });

  final String id;
  final String sku;
  final String? barcode;
  final String nameId;
  final int price;
  final bool ppnExempt;
  final int stockQty;

  /// When true, every saleable physical lot must have an expiry date and FEFO
  /// excludes lots that are too close to expiry.
  final bool trackExpiry;

  /// Minimum remaining shelf life required at checkout.
  final int minShelfLifeDays;

  Product copyWith({
    String? id,
    String? sku,
    String? barcode,
    bool clearBarcode = false,
    String? nameId,
    int? price,
    bool? ppnExempt,
    int? stockQty,
    bool? trackExpiry,
    int? minShelfLifeDays,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      nameId: nameId ?? this.nameId,
      price: price ?? this.price,
      ppnExempt: ppnExempt ?? this.ppnExempt,
      stockQty: stockQty ?? this.stockQty,
      trackExpiry: trackExpiry ?? this.trackExpiry,
      minShelfLifeDays: minShelfLifeDays ?? this.minShelfLifeDays,
    );
  }
}
