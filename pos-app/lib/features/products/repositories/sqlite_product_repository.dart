// lib/features/products/repositories/sqlite_product_repository.dart

import 'package:sqflite/sqflite.dart';

import '../../../core/database/pos_database.dart';
import '../models/product.dart';

/// SQLite-backed product and inventory-lot repository.
class SqliteProductRepository {
  SqliteProductRepository(this._database);

  final PosDatabase _database;

  Future<void> upsert(Product product) async {
    _validate(product);

    await _database.database.rawInsert(
      '''
      INSERT INTO products(
        id, sku, barcode, name_id, price, ppn_exempt, stock_qty
      ) VALUES(?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        sku = excluded.sku,
        barcode = excluded.barcode,
        name_id = excluded.name_id,
        price = excluded.price,
        ppn_exempt = excluded.ppn_exempt,
        stock_qty = excluded.stock_qty
      ''',
      <Object?>[
        product.id,
        product.sku,
        product.barcode,
        product.nameId,
        product.price,
        product.ppnExempt ? 1 : 0,
        product.stockQty,
      ],
    );
  }

  Future<Product?> findById(String id) async {
    final rows = await _database.database.query(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  /// Adds a FIFO cost layer and increases the product stock atomically.
  Future<void> addInventoryLot({
    required String id,
    required String productId,
    required int quantity,
    required int unitCost,
    required DateTime acquiredAtUtc,
  }) async {
    if (id.trim().isEmpty) {
      throw const ProductValidationException('ID lot wajib diisi.');
    }
    if (productId.trim().isEmpty) {
      throw const ProductValidationException('ID produk wajib diisi.');
    }
    if (quantity <= 0) {
      throw const ProductValidationException(
        'Jumlah lot harus lebih dari nol.',
      );
    }
    if (unitCost < 0) {
      throw const ProductValidationException(
        'Harga pokok tidak boleh negatif.',
      );
    }

    await _database.transaction((transaction) async {
      final productRows = await transaction.query(
        'products',
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[productId],
        limit: 1,
      );
      if (productRows.isEmpty) {
        throw ProductNotFoundException(productId);
      }

      await transaction.insert(
        'inventory_lots',
        <String, Object?>{
          'id': id.trim(),
          'product_id': productId.trim(),
          'acquired_at_utc': acquiredAtUtc.toUtc().toIso8601String(),
          'remaining_qty': quantity,
          'unit_cost': unitCost,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await transaction.rawUpdate(
        '''
        UPDATE products
        SET stock_qty = stock_qty + ?
        WHERE id = ?
        ''',
        <Object?>[quantity, productId],
      );
    });
  }

  void _validate(Product product) {
    if (product.id.trim().isEmpty) {
      throw const ProductValidationException('ID produk wajib diisi.');
    }
    if (product.sku.trim().isEmpty) {
      throw const ProductValidationException('SKU wajib diisi.');
    }
    if (product.nameId.trim().isEmpty) {
      throw const ProductValidationException('Nama produk wajib diisi.');
    }
    if (product.price < 0) {
      throw const ProductValidationException('Harga tidak boleh negatif.');
    }
    if (product.stockQty < 0) {
      throw const ProductValidationException('Stok tidak boleh negatif.');
    }
  }

  Product _fromRow(Map<String, Object?> row) {
    return Product(
      id: row['id']! as String,
      sku: row['sku']! as String,
      barcode: row['barcode'] as String?,
      nameId: row['name_id']! as String,
      price: row['price']! as int,
      ppnExempt: (row['ppn_exempt']! as int) == 1,
      stockQty: row['stock_qty']! as int,
    );
  }
}

class ProductRepositoryException implements Exception {
  const ProductRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductValidationException extends ProductRepositoryException {
  const ProductValidationException(super.message);
}

class ProductNotFoundException extends ProductRepositoryException {
  ProductNotFoundException(String productId)
      : super('Produk "$productId" tidak ditemukan.');
}
