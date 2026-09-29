// test/app_smoke_test.dart

import 'package:berkahtigaputeri_pos/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menampilkan nama aplikasi', (tester) async {
    await tester.pumpWidget(const BerkahTigaPuteriApp());

    expect(find.text('Berkah Tiga Puteri POS'), findsOneWidget);
  });
}
