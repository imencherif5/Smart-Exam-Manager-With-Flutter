import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const QcmApp());
}

class QcmApp extends StatelessWidget {
  const QcmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QCM Prof',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const HomeScreen(),
  );
}
