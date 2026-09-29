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
  });

  final String id;
  final String sku;
  final String? barcode;
  final String nameId;
  final int price;
  final bool ppnExempt;
  final int stockQty;

  Product copyWith({
    String? id,
    String? sku,
    String? barcode,
    bool clearBarcode = false,
    String? nameId,
    int? price,
    bool? ppnExempt,
    int? stockQty,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      nameId: nameId ?? this.nameId,
      price: price ?? this.price,
      ppnExempt: ppnExempt ?? this.ppnExempt,
      stockQty: stockQty ?? this.stockQty,
    );
  }
}
