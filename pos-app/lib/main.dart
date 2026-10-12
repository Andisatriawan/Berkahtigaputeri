import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_identity_store.dart';
import 'core/config/config_service.dart';
import 'core/database/pos_database.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final database = await PosDatabase.openDefault();
  final identityStore = AppIdentityStore(preferences);

  SupabaseClient? authClient;
  ConfigService? configService;
  String cloudConfigurationMessage;

  if (_supabaseUrl.trim().isEmpty ||
      _supabasePublishableKey.trim().isEmpty) {
    cloudConfigurationMessage =
        'Cloud login belum dikonfigurasi pada build ini. '
        'Atur SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY saat build. '
        'Mode lokal tetap tersedia.';
  } else {
    try {
      // supabase_flutter persists/restores user sessions across app restarts.
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabasePublishableKey,
      );
      authClient = Supabase.instance.client;
      configService = ConfigService(authClient, preferences);
      cloudConfigurationMessage = '';
    } catch (_) {
      cloudConfigurationMessage =
          'Supabase tidak dapat diinisialisasi. Periksa konfigurasi build '
          'dan koneksi; mode lokal tetap tersedia.';
    }
  }

  runApp(
    BerkahTigaPuteriApp(
      database: database,
      authClient: authClient,
      configService: configService,
      identityStore: identityStore,
      cloudConfigurationMessage: cloudConfigurationMessage,
    ),
  );
}

class BerkahTigaPuteriApp extends StatelessWidget {
  const BerkahTigaPuteriApp({
    super.key,
    this.database,
    this.authClient,
    this.configService,
    this.identityStore,
    this.cloudConfigurationMessage,
  });

  final PosDatabase? database;
  final SupabaseClient? authClient;
  final ConfigService? configService;
  final AppIdentityStore? identityStore;
  final String? cloudConfigurationMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berkah Tiga Puteri POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF137A4B),
        useMaterial3: true,
      ),
      home: database == null || identityStore == null
          ? const Scaffold(
              body: Center(child: Text('Berkah Tiga Puteri POS')),
            )
          : _AppGate(
              database: database!,
              authClient: authClient,
              configService: configService,
              identityStore: identityStore!,
              cloudConfigurationMessage: cloudConfigurationMessage,
            ),
    );
  }
}

/// Keeps the auth/local-mode switch inside one stable route. Login/logout
/// therefore replaces the app's current screen without leaving Settings on top
/// of an obsolete authenticated route.
class _AppGate extends StatefulWidget {
  const _AppGate({
    required this.database,
    required this.authClient,
    required this.configService,
    required this.identityStore,
    required this.cloudConfigurationMessage,
  });

  final PosDatabase database;
  final SupabaseClient? authClient;
  final ConfigService? configService;
  final AppIdentityStore identityStore;
  final String? cloudConfigurationMessage;

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _localOnly = false;

  void _continueLocalOnly() {
    setState(() => _localOnly = true);
  }

  void _authenticated() {
    setState(() => _localOnly = false);
  }

  Future<void> _signOut() async {
    try {
      await widget.authClient?.auth.signOut();
    } catch (_) {
      // Do not continue to use the cloud client after a requested sign-out.
    }
    if (mounted) {
      setState(() => _localOnly = false);
    }
  }

  Widget _home({required bool localOnly}) {
    return HomeScreen(
      database: widget.database,
      identityStore: widget.identityStore,
      configService: localOnly ? null : widget.configService,
      onSignOut: !localOnly && widget.authClient != null ? _signOut : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localOnly) return _home(localOnly: true);

    final client = widget.authClient;
    if (client == null) {
      return LoginScreen(
        client: null,
        configurationMessage: widget.cloudConfigurationMessage,
        onAuthenticated: _authenticated,
        onContinueLocal: _continueLocalOnly,
      );
    }

    if (client.auth.currentSession != null) {
      return _home(localOnly: false);
    }

    return LoginScreen(
      client: client,
      configurationMessage: widget.cloudConfigurationMessage,
      onAuthenticated: _authenticated,
      onContinueLocal: _continueLocalOnly,
    );
  }
}
