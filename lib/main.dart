// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      home: const CheckAuthPage(),
    );
  }
}

class CheckAuthPage extends StatefulWidget {
  const CheckAuthPage({super.key});

  @override
  State<CheckAuthPage> createState() => _CheckAuthPageState();
}

class _CheckAuthPageState extends State<CheckAuthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarYRedirigir();
    });
  }

  Future<void> _inicializarYRedirigir() async {
    // 1. Inicializar Supabase sólo después de que el DOM ya cargó
    try {
      await Supabase.initialize(
        url: 'https://axmwslbcchqpcglxdzip.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4bXdzbGJjY2hxcGNnbHhkemlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTIwNTksImV4cCI6MjA5Njg2ODA1OX0.m6m88jGRGwsb81glmyvmVkDM3cfROdVZ4EmgobPy5Xo',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (e) {
      debugPrint("Supabase Init Notice: $e");
    }

    // 2. Evaluar sesión de usuario
    try {
      final prefs = await SharedPreferences.getInstance();
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
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LogueoPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFFFFF),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF007AFF),
          strokeWidth: 3,
        ),
      ),
    );
  }
}