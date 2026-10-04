import 'dart:convert';
import 'dart:developer' as developer;

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
      final features = await _getFeaturesFromAppConfig(tenantId);
      await _preferences.setString(cacheKey, jsonEncode(features.toJson()));
      return TenantFeaturesResult(value: features, fromCache: false);
    } catch (appConfigError) {
      // DEPRECATED: tenants.features removed, Final Pos uses app_config
      developer.log(
        'WARNING: app_config features unavailable for $tenantId; '
        'falling back to deprecated tenants.features for legacy tenant compatibility.',
        name: 'ConfigService',
        error: appConfigError,
      );

      try {
        final row = await _client
            .from('tenants')
            .select('features')
            .eq('tenant_id', tenantId)
            .single();
        final features = TenantFeatures.fromJson(_asJsonMap(row['features']));
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
  }

  Future<TenantFeatures> _getFeaturesFromAppConfig(String tenantId) async {
    final tenantKey = 'tenant:$tenantId';
    final tenantRow = await _client
        .from('app_config')
        .select('value')
        .eq('key', tenantKey)
        .maybeSingle();

    if (tenantRow == null || tenantRow['value'] == null) {
      throw StateError('Missing app_config row $tenantKey');
    }

    final tenantValue = _asJsonMap(tenantRow['value']);
    final rawTemplate = tenantValue['template_id'] ?? tenantValue['template'];
    final templateId = rawTemplate?.toString().trim().toUpperCase();

    final orderedKeys = <String>[
      'global',
      if (templateId != null && templateId.isNotEmpty) 'template:$templateId',
      tenantKey,
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

    final effective = mergeLayers(
      orderedKeys.map(
        (key) => valuesByKey[key] ?? const <String, dynamic>{},
      ),
    );
    final rawFeatures = effective['features'];
    if (rawFeatures is Map) {
      return TenantFeatures.fromJson(Map<String, dynamic>.from(rawFeatures));
    }

    if (effective.containsKey('pos_enabled') ||
        effective.containsKey('akuntansi_enabled')) {
      return TenantFeatures(
        pos: effective['pos_enabled'] == true,
        akuntansi: effective['akuntansi_enabled'] == true,
      );
    }

    throw const FormatException(
      'Effective app_config does not contain tenant feature flags',
    );
  }

  Future<Map<String, dynamic>> _fallbackSelectAndMerge({
    required String tenantId,
    required String deviceId,
    required String service,
  }) async {
    final tenantKey = 'tenant:$tenantId';
    String? templateId;

    final tenantRow = await _client
        .from('app_config')
        .select('value')
        .eq('key', tenantKey)
        .maybeSingle();

    if (tenantRow != null && tenantRow['value'] != null) {
      final tenantValue = _asJsonMap(tenantRow['value']);
      final rawTemplate = tenantValue['template_id'] ?? tenantValue['template'];
      if (rawTemplate != null && rawTemplate.toString().trim().isNotEmpty) {
        templateId = rawTemplate.toString().trim().toUpperCase();
      }
    }

    final orderedKeys = <String>[
      'global',
      if (templateId != null) 'template:$templateId',
      tenantKey,
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
      final value = _asJsonMap(row['value']);
      if (key == 'tenant:$tenantId:service:$service' &&
          value['inherited_from_template'] != null) {
        value
          ..remove('mdr')
          ..remove('mdr_pos')
          ..remove('qris_mdr')
          ..remove('mdr_%');
      }
      valuesByKey[key] = value;
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
