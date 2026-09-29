// lib/features/pos/checkout/sqlite_sale_repository.dart

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/pos_database.dart';
import '../../../core/time/business_date.dart';
import '../../accounting/models/coa_account.dart';
import '../../accounting/models/journal_entry.dart';
import '../../accounting/repositories/sqlite_journal_repository.dart';
import '../../accounting/services/journal_service.dart';
import '../../products/models/product.dart';
import '../../products/repositories/sqlite_product_repository.dart';
import '../cart/sale_calculator.dart';
import 'payment_service.dart';

/// SQLite implementation of the atomic POS sale boundary.
class SqliteSaleRepository implements SaleRepository {
  const SqliteSaleRepository(this._database);

  final PosDatabase _database;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    request.validate();

    final transactionId = request.transactionId.trim();
    final fingerprint = _fingerprint(request);

    return _database.transaction<PaymentResult>((transaction) async {
      final existingRows = await transaction.query(
        'sales',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[transactionId],
        limit: 1,
      );

      final journalRepository = SqliteJournalRepository(
        _database,
        executor: transaction,
      );
      final journalService = JournalService(journalRepository);

      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        if (existing['request_fingerprint'] != fingerprint) {
          throw DuplicateTransactionIdException(transactionId);
        }

        final journal =
            await journalService.findByTransactionId(transactionId);
        if (journal == null) {
          throw const SaleDataIntegrityException(
            'Jurnal transaksi yang sudah tersimpan tidak ditemukan.',
          );
        }

        return _resultFromRow(
          saleRow: existing,
          journal: journal,
          alreadyProcessed: true,
        );
      }

      final products = <Product>[];
      final pricingLines = <SalePricingLine>[];

      for (final input in request.lines) {
        final rows = await transaction.query(
          'products',
          where: 'id = ?',
          whereArgs: <Object?>[input.productId.trim()],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw ProductNotFoundException(input.productId.trim());
        }

        final product = _productFromRow(rows.first);
        products.add(product);
        pricingLines.add(
          SalePricingLine(
            productId: product.id,
            quantity: input.quantity,
            unitPrice: product.price,
            itemDiscountAmount: input.itemDiscountAmount,
            ppnExempt: product.ppnExempt,
          ),
        );
      }

      final calculation = SaleCalculator.calculate(
        lines: pricingLines,
        transactionDiscountAmount: request.transactionDiscountAmount,
      );

      final cogsByLine = <int>[];
      var totalCogs = 0;

      for (var lineIndex = 0;
          lineIndex < request.lines.length;
          lineIndex++) {
        final product = products[lineIndex];
        final requestedQuantity = request.lines[lineIndex].quantity;

        if (product.stockQty < requestedQuantity) {
          throw InsufficientStockException(
            productName: product.nameId,
            available: product.stockQty,
            requested: requestedQuantity,
          );
        }

        final cogs = await _consumeFifo(
          transaction: transaction,
          transactionId: transactionId,
          lineIndex: lineIndex,
          product: product,
          quantity: requestedQuantity,
          occurredAtUtc: request.occurredAtUtc.toUtc(),
        );

        cogsByLine.add(cogs);
        totalCogs += cogs;
      }

      final businessDate =
          BusinessDate.fromUtc(request.occurredAtUtc.toUtc());
      final saleId = 'sale:$transactionId';
      final createdAtUtc = DateTime.now().toUtc().toIso8601String();

      await transaction.insert(
        'sales',
        <String, Object?>{
          'id': saleId,
          'transaction_id': transactionId,
          'request_fingerprint': fingerprint,
          'occurred_at_utc':
              request.occurredAtUtc.toUtc().toIso8601String(),
          'business_date': businessDate,
          'timezone': request.timezone,
          'gross_amount': calculation.grossAmount,
          'item_discount_amount': calculation.itemDiscountAmount,
          'transaction_discount_amount':
              calculation.transactionDiscountAmount,
          'discount_amount': calculation.discountAmount,
          'taxable_dpp': calculation.taxableDpp,
          'exempt_dpp': calculation.exemptDpp,
          'dpp': calculation.dpp,
          'ppn_amount': calculation.ppnAmount,
          'grand_total': calculation.grandTotal,
          'cogs_amount': totalCogs,
          'payment_method': request.method.name,
          'created_at_utc': createdAtUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (var index = 0; index < calculation.lines.length; index++) {
        final line = calculation.lines[index];
        await transaction.insert(
          'sale_items',
          <String, Object?>{
            'id': '$saleId:item:$index',
            'sale_id': saleId,
            'line_no': index,
            'product_id': line.source.productId,
            'quantity': line.source.quantity,
            'unit_price': line.source.unitPrice,
            'gross_amount': line.grossAmount,
            'item_discount_amount': line.itemDiscountAmount,
            'transaction_discount_amount':
                line.transactionDiscountAmount,
            'discount_amount': line.discountAmount,
            'dpp': line.dpp,
            'ppn_exempt': line.ppnExempt ? 1 : 0,
            'cogs_amount': cogsByLine[index],
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      final journal = await journalService.post(
        _buildSaleJournal(
          request: request,
          transactionId: transactionId,
          calculation: calculation,
          totalCogs: totalCogs,
          businessDate: businessDate,
        ),
      );

      await transaction.insert(
        'outbox_events',
        <String, Object?>{
          'id': 'outbox:sale:$transactionId',
          'entity_type': 'sale',
          'entity_id': saleId,
          'payload': jsonEncode(
            <String, Object?>{
              'saleId': saleId,
              'transactionId': transactionId,
              'businessDate': businessDate,
              'grandTotal': calculation.grandTotal,
              'ppnAmount': calculation.ppnAmount,
              'paymentMethod': request.method.name,
            },
          ),
          'status': 'pending',
          'retry_count': 0,
          'created_at_utc': createdAtUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return PaymentResult(
        saleId: saleId,
        journalEntry: journal,
        grossAmount: calculation.grossAmount,
        discountAmount: calculation.discountAmount,
        taxableDpp: calculation.taxableDpp,
        exemptDpp: calculation.exemptDpp,
        ppnAmount: calculation.ppnAmount,
        grandTotal: calculation.grandTotal,
        cogsAmount: totalCogs,
        businessDate: businessDate,
        alreadyProcessed: false,
      );
    });
  }

  Future<int> _consumeFifo({
    required Transaction transaction,
    required String transactionId,
    required int lineIndex,
    required Product product,
    required int quantity,
    required DateTime occurredAtUtc,
  }) async {
    final lots = await transaction.query(
      'inventory_lots',
      where: 'product_id = ? AND remaining_qty > 0',
      whereArgs: <Object?>[product.id],
      orderBy: 'acquired_at_utc, id',
    );

    final availableInLots = lots.fold<int>(
      0,
      (sum, row) => sum + (row['remaining_qty']! as int),
    );

    if (availableInLots < quantity) {
      throw InventoryDataIntegrityException(
        'Layer FIFO untuk "${product.nameId}" hanya $availableInLots, '
        'sedangkan stok produk tercatat ${product.stockQty}.',
      );
    }

    var remaining = quantity;
    var cogs = 0;
    var movementIndex = 0;

    for (final lot in lots) {
      if (remaining == 0) {
        break;
      }

      final lotRemaining = lot['remaining_qty']! as int;
      final unitCost = lot['unit_cost']! as int;
      final take = remaining < lotRemaining ? remaining : lotRemaining;

      await transaction.update(
        'inventory_lots',
        <String, Object?>{
          'remaining_qty': lotRemaining - take,
        },
        where: 'id = ?',
        whereArgs: <Object?>[lot['id']],
      );

      final totalCost = take * unitCost;
      cogs += totalCost;

      await transaction.insert(
        'stock_movements',
        <String, Object?>{
          'id':
              'stock:$transactionId:$lineIndex:$movementIndex',
          'product_id': product.id,
          'reference_id': transactionId,
          'movement_type': 'sale',
          'quantity_delta': -take,
          'unit_cost': unitCost,
          'total_cost': totalCost,
          'occurred_at_utc': occurredAtUtc.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      remaining -= take;
      movementIndex++;
    }

    final updatedRows = await transaction.rawUpdate(
      '''
      UPDATE products
      SET stock_qty = stock_qty - ?
      WHERE id = ? AND stock_qty >= ?
      ''',
      <Object?>[quantity, product.id, quantity],
    );

    if (updatedRows != 1) {
      throw InsufficientStockException(
        productName: product.nameId,
        available: product.stockQty,
        requested: quantity,
      );
    }

    return cogs;
  }

  JournalEntry _buildSaleJournal({
    required PaymentRequest request,
    required String transactionId,
    required SaleCalculation calculation,
    required int totalCogs,
    required String businessDate,
  }) {
    final lines = <JournalLine>[];

    if (calculation.grandTotal > 0) {
      lines.add(
        JournalLine(
          accountCode: _paymentAccountCode(request.method),
          debit: calculation.grandTotal,
          credit: 0,
        ),
      );
    }

    if (calculation.discountAmount > 0) {
      lines.add(
        JournalLine(
          accountCode: CoaAccounts.salesDiscounts.code,
          debit: calculation.discountAmount,
          credit: 0,
        ),
      );
    }

    lines.add(
      JournalLine(
        accountCode: CoaAccounts.sales.code,
        debit: 0,
        credit: calculation.grossAmount,
      ),
    );

    if (calculation.ppnAmount > 0) {
      // Ordinary sales always credit the approved PPN payable account.
      lines.add(
        JournalLine(
          accountCode: CoaAccounts.ppnPayable.code,
          debit: 0,
          credit: calculation.ppnAmount,
        ),
      );
    }

    if (totalCogs > 0) {
      lines
        ..add(
          JournalLine(
            accountCode: CoaAccounts.cogs.code,
            debit: totalCogs,
            credit: 0,
          ),
        )
        ..add(
          JournalLine(
            accountCode: CoaAccounts.inventory.code,
            debit: 0,
            credit: totalCogs,
          ),
        );
    }

    return JournalEntry(
      id: 'journal:sale:$transactionId',
      date: request.occurredAtUtc.toUtc(),
      transactionId: transactionId,
      businessDate: businessDate,
      timezone: request.timezone,
      lines: lines,
    );
  }

  String _paymentAccountCode(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return CoaAccounts.cash.code;
      case PaymentMethod.qris:
        return CoaAccounts.qris.code;
      case PaymentMethod.transfer:
        return CoaAccounts.bankTransfer.code;
    }
  }

  Product _productFromRow(Map<String, Object?> row) {
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

  String _fingerprint(PaymentRequest request) {
    return jsonEncode(
      <String, Object?>{
        'transactionId': request.transactionId.trim(),
        'method': request.method.name,
        'occurredAtUtc':
            request.occurredAtUtc.toUtc().toIso8601String(),
        'transactionDiscountAmount':
            request.transactionDiscountAmount,
        'timezone': request.timezone,
        'lines': request.lines
            .map(
              (line) => <String, Object?>{
                'productId': line.productId.trim(),
                'quantity': line.quantity,
                'itemDiscountAmount': line.itemDiscountAmount,
              },
            )
            .toList(growable: false),
      },
    );
  }

  PaymentResult _resultFromRow({
    required Map<String, Object?> saleRow,
    required JournalEntry journal,
    required bool alreadyProcessed,
  }) {
    return PaymentResult(
      saleId: saleRow['id']! as String,
      journalEntry: journal,
      grossAmount: saleRow['gross_amount']! as int,
      discountAmount: saleRow['discount_amount']! as int,
      taxableDpp: saleRow['taxable_dpp']! as int,
      exemptDpp: saleRow['exempt_dpp']! as int,
      ppnAmount: saleRow['ppn_amount']! as int,
      grandTotal: saleRow['grand_total']! as int,
      cogsAmount: saleRow['cogs_amount']! as int,
      businessDate: saleRow['business_date']! as String,
      alreadyProcessed: alreadyProcessed,
    );
  }
}

class SaleRepositoryException implements Exception {
  const SaleRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsufficientStockException extends SaleRepositoryException {
  InsufficientStockException({
    required String productName,
    required int available,
    required int requested,
  }) : super(
          'Stok "$productName" tidak cukup. '
          'Tersedia $available, diminta $requested.',
        );
}

class InventoryDataIntegrityException extends SaleRepositoryException {
  const InventoryDataIntegrityException(super.message);
}

class SaleDataIntegrityException extends SaleRepositoryException {
  const SaleDataIntegrityException(super.message);
}
