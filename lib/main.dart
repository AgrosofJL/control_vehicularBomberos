// ESTO LO MODIFIQUE
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'loguer.dart';

void main() async {
  // 1. OBLIGATORIO: Siempre en la primera línea
  WidgetsFlutterBinding.ensureInitialized();

  // 2. OBLIGATORIO: Inicialización multiplataforma de SQLite
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. Inicializar localización de fechas en español
  try {
    await initializeDateFormatting('es', null);
  } catch (e) {
    debugPrint("Aviso al inicializar formato de fechas: $e");
  }

  // 4. Inicializar Supabase
  try {
    await Supabase.initialize(
      url: 'https://axmwslbcchqpcglxdzip.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4bXdzbGJjY2hxcGNnbHhkemlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTIwNTksImV4cCI6MjA5Njg2ODA1OX0.m6m88jGRGwsb81glmyvmVkDM3cfROdVZ4EmgobPy5Xo',
    );
  } catch (e) {
    debugPrint("Aviso al inicializar Supabase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checklist Vehicular',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const LogueoPage(),
    );
  }
}