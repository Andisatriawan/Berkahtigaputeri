import 'package:berkahtigaputeri_pos/core/config/app_identity_store.dart';
import 'package:berkahtigaputeri_pos/core/database/pos_database.dart';
import 'package:berkahtigaputeri_pos/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _settle(WidgetTester tester, String checkpoint) async {
  print('PUMP_SETTLE_BEGIN:$checkpoint');
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  print('PUMP_SETTLE_DONE:$checkpoint');
}

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
    await _settle(tester, 'initial app');

    // No Supabase client is injected in this test, so enter explicit local-only
    // mode rather than implying the cloud account is authenticated.
    expect(find.text('Lanjutkan sebagai kasir lokal'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan sebagai kasir lokal'));
    await _settle(tester, 'local mode');

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Buka kasir'), findsOneWidget);

    await tester.tap(find.text('Produk').last);
    await _settle(tester, 'products tab');
    expect(find.text('Tambah produk'), findsOneWidget);

    await tester.tap(find.text('Kasir'));
    await _settle(tester, 'cashier tab');
    expect(find.text('Katalog produk'), findsOneWidget);
    expect(find.text('Selesaikan checkout'), findsOneWidget);

    await tester.tap(find.text('Stok'));
    await _settle(tester, 'stock tab');
    expect(find.text('Ringkasan stok lokal'), findsOneWidget);

    await tester.tap(find.text('Laporan'));
    await _settle(tester, 'reports tab');
    expect(find.text('Transaksi terbaru'), findsOneWidget);
  });
}
