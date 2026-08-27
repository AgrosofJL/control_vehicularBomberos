// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loguer.dart';
import 'menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const SplashInitializerPage(),
    );
  }
}

class SplashInitializerPage extends StatefulWidget {
  const SplashInitializerPage({super.key});

  @override
  State<SplashInitializerPage> createState() => _SplashInitializerPageState();
}

class _SplashInitializerPageState extends State<SplashInitializerPage> {
  String _estadoCarga = "Iniciando servicios...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarTodo();
    });
  }

  Future<void> _iniciarTodo() async {
    // 1. Configurar SQLite Web
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
      } catch (e) {
        debugPrint("Notice SQLite: $e");
      }
    }

    // 2. Inicializar Supabase
    setState(() => _estadoCarga = "Conectando con base de datos...");
    try {
      await Supabase.initialize(
        url: 'https://axmwslbcchqpcglxdzip.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4bXdzbGJjY2hxcGNnbHhkemlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTIwNTksImV4cCI6MjA5Njg2ODA1OX0.m6m88jGRGwsb81glmyvmVkDM3cfROdVZ4EmgobPy5Xo',
      );
    } catch (e) {
      debugPrint("Notice Supabase: $e");
    }

    // 3. Evaluar sesión de usuario
    setState(() => _estadoCarga = "Comprobando credenciales...");
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool tieneSesion = prefs.getBool('isLoggedIn') ?? false;

      if (!mounted) return;

      if (tieneSesion) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LogueoPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LogueoPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF007AFF),
              strokeWidth: 3,
            ),
            const SizedBox(height: 25),
            Text(
              _estadoCarga,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}