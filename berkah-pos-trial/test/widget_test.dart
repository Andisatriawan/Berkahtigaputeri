import 'package:flutter_test/flutter_test.dart';
import 'package:berkah_pos/main.dart';

void main() {
  testWidgets('login presents a free trial and external sales contact', (tester) async {
    await tester.pumpWidget(const BerkahApp());

    expect(find.text('Mulai Trial Gratis'), findsOneWidget);
    expect(find.text('Hubungi Sales via WhatsApp'), findsOneWidget);
    expect(find.text('PT Berkah Tiga Puteri'), findsOneWidget);
  });
}
