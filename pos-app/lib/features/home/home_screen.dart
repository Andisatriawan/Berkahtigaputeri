import 'package:flutter/material.dart';

import '../../core/config/app_identity_store.dart';
import '../../core/config/config_service.dart';

class HomeScreen extends StatefulWidget {
  final ConfigService configService;
  final AppIdentityStore identityStore;

  const HomeScreen({
    super.key,
    required this.configService,
    required this.identityStore,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _uatTenants = <String>[
    'berkah_sumber',
    'clientA',
    'clientB',
  ];

  late String _tenantId;
  late final TextEditingController _deviceController;

  TenantFeatures? _features;
  Map<String, dynamic>? _effectivePos;
  bool _fromCache = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tenantId = widget.identityStore.tenantId;
    _deviceController = TextEditingController(
      text: widget.identityStore.deviceId,
    );
    _reload();
  }

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceId = _deviceController.text.trim().isEmpty
          ? AppIdentityStore.defaultDeviceId
          : _deviceController.text.trim();

      final config = await widget.configService.getEffectiveConfig(
        tenantId: _tenantId,
        deviceId: deviceId,
        service: 'pos',
      );
      final features = await widget.configService.getFeatures(_tenantId);

      if (!mounted) return;
      setState(() {
        _effectivePos = config.value;
        _features = features.value;
        _fromCache = config.fromCache || features.fromCache;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectTenant(String tenantId) async {
    await widget.identityStore.setTenantId(tenantId);
    if (!mounted) return;
    setState(() => _tenantId = tenantId);
    await _reload();
  }

  Future<void> _saveDeviceAndReload() async {
    final deviceId = _deviceController.text.trim().isEmpty
        ? AppIdentityStore.defaultDeviceId
        : _deviceController.text.trim();
    _deviceController.text = deviceId;
    await widget.identityStore.setDeviceId(deviceId);
    await _reload();
  }

  String get _mdrText {
    final config = _effectivePos;
    if (config == null) return '-';
    final value = config['mdr'] ?? config['qris_mdr'];
    if (value == null) return '-';
    return '$value%';
  }

  @override
  Widget build(BuildContext context) {
    final features = _features;
    final tenants = _uatTenants.contains(_tenantId)
        ? _uatTenants
        : <String>[_tenantId, ..._uatTenants];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berkah Tiga Puteri POS'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh config',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SettingsCard(
            tenantId: _tenantId,
            tenants: tenants,
            deviceController: _deviceController,
            onTenantChanged: _loading ? null : _selectTenant,
            onSaveDevice: _loading ? null : _saveDeviceAndReload,
          ),
          const SizedBox(height: 12),
          _StatusCard(
            loading: _loading,
            fromCache: _fromCache,
            error: _error,
            mdr: _mdrText,
          ),
          const SizedBox(height: 12),
          if (!_loading && _error == null && features != null) ...<Widget>[
            const Text(
              'Menu layanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                if (features.pos)
                  const _ServiceCard(
                    icon: Icons.point_of_sale,
                    title: 'POS',
                    subtitle: 'Kasir dan pembayaran',
                  ),
                if (features.akuntansi)
                  const _ServiceCard(
                    icon: Icons.account_balance,
                    title: 'Akuntansi',
                    subtitle: 'Jurnal dan laporan',
                  ),
              ],
            ),
            if (!features.pos && !features.akuntansi)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Tidak ada layanan aktif untuk tenant ini.'),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String tenantId;
  final List<String> tenants;
  final TextEditingController deviceController;
  final ValueChanged<String>? onTenantChanged;
  final VoidCallback? onSaveDevice;

  const _SettingsCard({
    required this.tenantId,
    required this.tenants,
    required this.deviceController,
    required this.onTenantChanged,
    required this.onSaveDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Settings / Tenant UAT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tenantId,
              decoration: const InputDecoration(
                labelText: 'tenant_id',
                border: OutlineInputBorder(),
              ),
              items: tenants
                  .map(
                    (tenant) => DropdownMenuItem<String>(
                      value: tenant,
                      child: Text(tenant),
                    ),
                  )
                  .toList(),
              onChanged: onTenantChanged == null
                  ? null
                  : (value) {
                      if (value != null) onTenantChanged!(value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deviceController,
              decoration: const InputDecoration(
                labelText: 'device_id',
                helperText: 'Default UAT: infinix_xos_123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onSaveDevice,
              icon: const Icon(Icons.save),
              label: const Text('Simpan device & reload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool loading;
  final bool fromCache;
  final String? error;
  final String mdr;

  const _StatusCard({
    required this.loading,
    required this.fromCache,
    required this.error,
    required this.mdr,
  });

  @override
  Widget build(BuildContext context) {
    String status;
    if (loading) {
      status = 'Memuat config 3 layer...';
    } else if (error != null) {
      status = 'Config gagal dimuat: $error';
    } else if (fromCache) {
      status = 'CACHE OFFLINE';
    } else {
      status = 'LIVE SUPABASE';
    }

    return Card(
      child: ListTile(
        leading: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(fromCache ? Icons.offline_bolt : Icons.cloud_done),
        title: Text(status),
        subtitle: Text('MDR efektif POS: $mdr'),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
