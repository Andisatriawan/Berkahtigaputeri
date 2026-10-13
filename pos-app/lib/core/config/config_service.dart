import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantFeatures {
  final bool pos;
  final bool akuntansi;

  const TenantFeatures({
    required this.pos,
    required this.akuntansi,
  });

  factory TenantFeatures.fromJson(Map<String, dynamic> json) {
    return TenantFeatures(
      pos: json['pos'] == true,
      akuntansi: json['akuntansi'] == true,
    );
  }

  /// Extract feature flags from the authenticated, effective app_config result.
  /// This deliberately avoids the deprecated tenants.features projection.
  factory TenantFeatures.fromEffectiveConfig(Map<String, dynamic> config) {
    final rawFeatures = config['features'];
    if (rawFeatures is Map) {
      return TenantFeatures.fromJson(Map<String, dynamic>.from(rawFeatures));
    }

    if (config.containsKey('pos_enabled') ||
        config.containsKey('akuntansi_enabled')) {
      return TenantFeatures(
        pos: config['pos_enabled'] == true,
        akuntansi: config['akuntansi_enabled'] == true,
      );
    }

    throw const FormatException(
      'Effective app_config does not contain tenant feature flags',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pos': pos,
        'akuntansi': akuntansi,
      };
}

class EffectiveConfigResult {
  final Map<String, dynamic> value;
  final bool fromCache;

  const EffectiveConfigResult({
    required this.value,
    required this.fromCache,
  });
}

class ConfigService {
  final SupabaseClient _client;
  final SharedPreferences _preferences;

  ConfigService(this._client, this._preferences);

  /// True only when Supabase has an authenticated user session.
  /// A publishable key plus tenant/device strings is not authentication.
  bool get hasAuthenticatedSession => _client.auth.currentSession != null;

  Future<EffectiveConfigResult> getEffectiveConfig({
    required String tenantId,
    required String deviceId,
    required String service,
  }) async {
    final cacheKey = _effectiveCacheKey(tenantId, deviceId, service);

    // The server RPC is the only remote path for raw layered configuration.
    // Never SELECT GLOBAL/TEMPLATE/TENANT/SERVICE rows from the client.
    if (!hasAuthenticatedSession) {
      throw StateError(
        'An authenticated Supabase session is required for effective configuration.',
      );
    }

    try {
      final response = await _client.rpc(
        'get_effective_config',
        params: <String, dynamic>{
          'p_tenant': tenantId,
          'p_device': deviceId,
          'p_service': service,
        },
      );
      final effective = _asJsonMap(response);

      await _preferences.setString(cacheKey, jsonEncode(effective));
      return EffectiveConfigResult(value: effective, fromCache: false);
    } catch (_) {
      // Offline fallback is limited to the previously returned effective value
      // for this exact tenant/device/service tuple, never raw table rows.
      final cached = _preferences.getString(cacheKey);
      if (cached == null) rethrow;
      return EffectiveConfigResult(
        value: _asJsonMap(jsonDecode(cached)),
        fromCache: true,
      );
    }
  }

  static Map<String, dynamic> mergeLayers(
    Iterable<Map<String, dynamic>> layers,
  ) {
    final merged = <String, dynamic>{};
    for (final layer in layers) {
      merged.addAll(layer);
    }
    return merged;
  }

  static Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const FormatException('Expected JSON object');
  }

  static String _effectiveCacheKey(
    String tenantId,
    String deviceId,
    String service,
  ) =>
      'p6.effective.$tenantId.$deviceId.$service';

}
