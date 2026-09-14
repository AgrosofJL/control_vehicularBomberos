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
  
  // ==========================================
  // ACA ES LO NUEVO: Anula el fallo de init en web de google_fonts
  // ==========================================
  GoogleFonts.config.allowRuntimeFetching = false;
  
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _arrancar();
    });
  }

  Future<void> _arrancar() async {
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
      debugPrint("Supabase notice: $e");
    }

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