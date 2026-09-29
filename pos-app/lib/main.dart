// lib/main.dart

import 'package:flutter/material.dart';

void main() {
  runApp(const BerkahTigaPuteriApp());
}

class BerkahTigaPuteriApp extends StatelessWidget {
  const BerkahTigaPuteriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berkah Tiga Puteri POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Berkah Tiga Puteri POS'),
        ),
      ),
    );
  }
}
