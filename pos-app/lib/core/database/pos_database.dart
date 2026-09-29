// lib/core/database/pos_database.dart

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database for the local-first POS.
///
/// Schema changes must increment [schemaVersion] and provide a migration.
class PosDatabase {
  PosDatabase._(this.database);

  static const int schemaVersion = 1;
  static const String fileName = 'berkahtigaputeri_pos.db';

  final Database database;

  static Future<PosDatabase> openDefault() async {
    final root = await getDatabasesPath();
    return openAt(p.join(root, fileName));
  }

  static Future<PosDatabase> openAt(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final db = await selectedFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      ),
    );
    return PosDatabase._(db);
  }

  Future<T> transaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) {
    return database.transaction<T>(action, exclusive: true);
  }

  Future<void> close() => database.close();

  static Future<void> _createSchema(
    Database database,
    int version,
  ) async {
    await database.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT,
        name_id TEXT NOT NULL,
        price INTEGER NOT NULL CHECK(price >= 0),
        ppn_exempt INTEGER NOT NULL CHECK(ppn_exempt IN (0, 1)),
        stock_qty INTEGER NOT NULL CHECK(stock_qty >= 0)
      )
    ''');

    await database.execute('''
      CREATE TABLE inventory_lots (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        acquired_at_utc TEXT NOT NULL,
        remaining_qty INTEGER NOT NULL CHECK(remaining_qty >= 0),
        unit_cost INTEGER NOT NULL CHECK(unit_cost >= 0),
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_inventory_lots_fifo
      ON inventory_lots(product_id, acquired_at_utc, id)
    ''');

    await database.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL UNIQUE,
        request_fingerprint TEXT NOT NULL,
        occurred_at_utc TEXT NOT NULL,
        business_date TEXT NOT NULL,
        timezone TEXT NOT NULL,
        gross_amount INTEGER NOT NULL,
        item_discount_amount INTEGER NOT NULL,
        transaction_discount_amount INTEGER NOT NULL,
        discount_amount INTEGER NOT NULL,
        taxable_dpp INTEGER NOT NULL,
        exempt_dpp INTEGER NOT NULL,
        dpp INTEGER NOT NULL,
        ppn_amount INTEGER NOT NULL,
        grand_total INTEGER NOT NULL,
        cogs_amount INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        created_at_utc TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        line_no INTEGER NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price INTEGER NOT NULL CHECK(unit_price >= 0),
        gross_amount INTEGER NOT NULL,
        item_discount_amount INTEGER NOT NULL,
        transaction_discount_amount INTEGER NOT NULL,
        discount_amount INTEGER NOT NULL,
        dpp INTEGER NOT NULL,
        ppn_exempt INTEGER NOT NULL CHECK(ppn_exempt IN (0, 1)),
        cogs_amount INTEGER NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id),
        FOREIGN KEY(product_id) REFERENCES products(id),
        UNIQUE(sale_id, line_no)
      )
    ''');

    await database.execute('''
      CREATE TABLE journals (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL UNIQUE,
        occurred_at_utc TEXT NOT NULL,
        business_date TEXT NOT NULL,
        timezone TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE journal_lines (
        journal_id TEXT NOT NULL,
        line_no INTEGER NOT NULL,
        account_code TEXT NOT NULL,
        debit INTEGER NOT NULL CHECK(debit >= 0),
        credit INTEGER NOT NULL CHECK(credit >= 0),
        PRIMARY KEY(journal_id, line_no),
        FOREIGN KEY(journal_id) REFERENCES journals(id)
      )
    ''');

    await database.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        reference_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity_delta INTEGER NOT NULL,
        unit_cost INTEGER NOT NULL CHECK(unit_cost >= 0),
        total_cost INTEGER NOT NULL CHECK(total_cost >= 0),
        occurred_at_utc TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_stock_movements_product
      ON stock_movements(product_id, occurred_at_utc)
    ''');

    await database.execute('''
      CREATE TABLE outbox_events (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_outbox_status
      ON outbox_events(status, created_at_utc)
    ''');
  }
}
