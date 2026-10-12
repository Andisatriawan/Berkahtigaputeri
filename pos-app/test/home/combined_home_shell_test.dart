import 'package:berkahtigaputeri_pos/core/config/app_identity_store.dart';
import 'package:berkahtigaputeri_pos/core/database/pos_database.dart';
import 'package:berkahtigaputeri_pos/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('combined POS shell exposes product, cashier, stock and reports',
      (tester) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final database = await PosDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      BerkahTigaPuteriApp(
        database: database,
        identityStore: AppIdentityStore(preferences),
      ),
    );
    await tester.pumpAndSettle();

    // No Supabase client is injected in this test, so enter explicit local-only
    // mode rather than implying the cloud account is authenticated.
    expect(find.text('Lanjutkan sebagai kasir lokal'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan sebagai kasir lokal'));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Buka kasir'), findsOneWidget);

    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah produk'), findsOneWidget);

    await tester.tap(find.text('Kasir'));
    await tester.pumpAndSettle();
    expect(find.text('Katalog produk'), findsOneWidget);
    expect(find.text('Selesaikan checkout'), findsOneWidget);

    await tester.tap(find.text('Stok'));
    await tester.pumpAndSettle();
    expect(find.text('Terima stok'), findsOneWidget);

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi terbaru'), findsOneWidget);
  });
}
