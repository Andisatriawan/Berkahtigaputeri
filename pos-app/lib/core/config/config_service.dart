import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

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

class TenantFeaturesResult {
  final TenantFeatures value;
  final bool fromCache;

  const TenantFeaturesResult({
    required this.value,
    required this.fromCache,
  });
}

class ConfigService {
  final SupabaseClient _client;
  final SharedPreferences _preferences;

  ConfigService(this._client, this._preferences);

  Future<EffectiveConfigResult> getEffectiveConfig({
    required String tenantId,
    required String deviceId,
    required String service,
  }) async {
    final cacheKey = _effectiveCacheKey(tenantId, deviceId, service);

    try {
      Map<String, dynamic> effective;
      try {
        final response = await _client.rpc(
          'get_effective_config',
          params: <String, dynamic>{
            'p_tenant': tenantId,
            'p_device': deviceId,
            'p_service': service,
          },
        );
        effective = _asJsonMap(response);
      } catch (_) {
        effective = await _fallbackSelectAndMerge(
          tenantId: tenantId,
          deviceId: deviceId,
          service: service,
        );
      }

      await _preferences.setString(cacheKey, jsonEncode(effective));
      return EffectiveConfigResult(value: effective, fromCache: false);
    } catch (_) {
      final cached = _preferences.getString(cacheKey);
      if (cached == null) rethrow;
      return EffectiveConfigResult(
        value: _asJsonMap(jsonDecode(cached)),
        fromCache: true,
      );
    }
  }

  Future<TenantFeaturesResult> getFeatures(String tenantId) async {
    final cacheKey = _featuresCacheKey(tenantId);

    try {
      final row = await _client
          .from('tenants')
          .select('features')
          .eq('tenant_id', tenantId)
          .single();

      final featuresJson = _asJsonMap(row['features']);
      final features = TenantFeatures.fromJson(featuresJson);
      await _preferences.setString(cacheKey, jsonEncode(features.toJson()));
      return TenantFeaturesResult(value: features, fromCache: false);
    } catch (_) {
      final cached = _preferences.getString(cacheKey);
      if (cached == null) rethrow;
      return TenantFeaturesResult(
        value: TenantFeatures.fromJson(_asJsonMap(jsonDecode(cached))),
        fromCache: true,
      );
    }
  }

  Future<Map<String, dynamic>> _fallbackSelectAndMerge({
    required String tenantId,
    required String deviceId,
    required String service,
  }) async {
    final orderedKeys = <String>[
      'global',
      'tenant:$tenantId',
      'tenant:$tenantId:service:$service',
      'device:$deviceId',
    ];

    final rows = await _client
        .from('app_config')
        .select('key,value')
        .inFilter('key', orderedKeys);

    final valuesByKey = <String, Map<String, dynamic>>{};
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final key = row['key'] as String?;
      if (key == null) continue;
      valuesByKey[key] = _asJsonMap(row['value']);
    }

    return mergeLayers(
      orderedKeys.map(
        (key) => valuesByKey[key] ?? const <String, dynamic>{},
      ),
    );
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

  static String _featuresCacheKey(String tenantId) =>
      'p6.features.$tenantId';
}
