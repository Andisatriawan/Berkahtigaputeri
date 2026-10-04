import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'core/config/app_identity_store.dart';
import 'core/config/config_service.dart';
import 'features/home/home_screen.dart';

const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://cztlmwzfrhyafgawphgw.supabase.co',
);
const String _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_LlsIisir66_TWiRRQ43l6A_yqoUDH13',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final client = SupabaseClient(_supabaseUrl, _supabasePublishableKey);

  runApp(
    BerkahTigaPuteriApp(
      configService: ConfigService(client, preferences),
      identityStore: AppIdentityStore(preferences),
    ),
  );
}

class BerkahTigaPuteriApp extends StatelessWidget {
  final ConfigService? configService;
  final AppIdentityStore? identityStore;

  const BerkahTigaPuteriApp({
    super.key,
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
      home: configService == null || identityStore == null
          ? const Scaffold(
              body: Center(
                child: Text('Berkah Tiga Puteri POS'),
              ),
            )
          : HomeScreen(
              configService: configService!,
              identityStore: identityStore!,
            ),
    );
  }
}
