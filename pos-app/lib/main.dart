import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'core/config/app_identity_store.dart';
import 'core/config/config_service.dart';
import 'core/database/pos_database.dart';
import 'features/home/home_screen.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final database = await PosDatabase.openDefault();
  final identityStore = AppIdentityStore(preferences);

  // Do not silently point a release build at a staging database. Cloud config
  // is opt-in at build time and remains unavailable until an authorized
  // Supabase session/device enrollment has been integrated.
  ConfigService? configService;
  if (_supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty) {
    final client = SupabaseClient(_supabaseUrl, _supabasePublishableKey);
    configService = ConfigService(client, preferences);
  }

  runApp(
    BerkahTigaPuteriApp(
      database: database,
      configService: configService,
      identityStore: identityStore,
    ),
  );
}

class BerkahTigaPuteriApp extends StatelessWidget {
  final PosDatabase? database;
  final ConfigService? configService;
  final AppIdentityStore? identityStore;

  const BerkahTigaPuteriApp({
    super.key,
    this.database,
    this.configService,
    this.identityStore,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berkah Tiga Puteri POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: database == null || identityStore == null
          ? const Scaffold(
              body: Center(
                child: Text('Berkah Tiga Puteri POS'),
              ),
            )
          : HomeScreen(
              database: database!,
              configService: configService,
              identityStore: identityStore!,
            ),
    );
  }
}
