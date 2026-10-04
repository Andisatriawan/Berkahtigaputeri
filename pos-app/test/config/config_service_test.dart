import 'package:berkahtigaputeri_pos/core/config/config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigService merge order', () {
    test('GLOBAL <- TENANT <- SERVICE <- DEVICE', () {
      final merged = ConfigService.mergeLayers(<Map<String, dynamic>>[
        <String, dynamic>{'mdr': 0.1, 'theme': 'global', 'printer': 'none'},
        <String, dynamic>{'mdr': 0.2, 'theme': 'tenant'},
        <String, dynamic>{'mdr': 0.5, 'qris_enabled': true},
        <String, dynamic>{'printer': 'PDF Preview'},
      ]);

      expect(merged['mdr'], 0.5);
      expect(merged['theme'], 'tenant');
      expect(merged['qris_enabled'], isTrue);
      expect(merged['printer'], 'PDF Preview');
    });

    test('tenant-scoped POS MDR values do not collide', () {
      final clientA = ConfigService.mergeLayers(<Map<String, dynamic>>[
        <String, dynamic>{'mdr': 0.1},
        <String, dynamic>{'tenant_id': 'clientA'},
        <String, dynamic>{'mdr': 0.5},
        const <String, dynamic>{},
      ]);
      final clientB = ConfigService.mergeLayers(<Map<String, dynamic>>[
        <String, dynamic>{'mdr': 0.1},
        <String, dynamic>{'tenant_id': 'clientB'},
        <String, dynamic>{'mdr': 0.7},
        const <String, dynamic>{},
      ]);

      expect(clientA['mdr'], 0.5);
      expect(clientB['mdr'], 0.7);
    });
  });

  group('TenantFeatures', () {
    test('clientA hides Akuntansi', () {
      final features = TenantFeatures.fromJson(
        <String, dynamic>{'pos': true, 'akuntansi': false},
      );

      expect(features.pos, isTrue);
      expect(features.akuntansi, isFalse);
    });

    test('clientB shows POS and Akuntansi', () {
      final features = TenantFeatures.fromJson(
        <String, dynamic>{'pos': true, 'akuntansi': true},
      );

      expect(features.pos, isTrue);
      expect(features.akuntansi, isTrue);
    });
  });
}
