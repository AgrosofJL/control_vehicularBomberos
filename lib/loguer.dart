// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base.dart';
import 'menu.dart';
import 'bajar.dart';

class LogueoPage extends StatefulWidget {
  const LogueoPage({super.key});

  @override
  State<LogueoPage> createState() => _LogueoPageState();
}

class _LogueoPageState extends State<LogueoPage> {
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  final Color _bgWhite = const Color(0xFFFFFFFF);
  final Color _inputBackground = const Color(0xFFF1F5F9);
  final Color _appleBlue = const Color(0xFF007AFF);
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);

  Future<void> _mostrarModalDevice() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _appleBlue.withOpacity(0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.phonelink_setup_rounded, color: _appleBlue),
            const SizedBox(width: 10),
            Text(
              "ACCESO WEB DIRECTO",
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Plataforma Web (Safari / PWA) habilitada para operaciones de campo.",
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _inputBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _appleBlue.withOpacity(0.15)),
              ),
              child: SelectableText(
                "DISPOSITIVO WEB AUTORIZADO",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _appleBlue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CERRAR",
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _intentarIngresar() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('usuarios')
          .select()
          .eq('correo', _correoController.text.trim())
          .eq('pass', _passController.text.trim())
          .maybeSingle();

      if (response != null) {
        if (!kIsWeb) {
          final dbHelper = DatabaseHelper();
          final localDb = await dbHelper.db;
          await localDb.insert(
            'usuarios',
            {
              'id': response['id'],
              'correo': response['usuario'] ?? response['correo'],
              'operario': response['operario'],
              'device': response['device'],
              'pass': response['pass'],
              'estado': response['estado'],
              'rol': response['rol'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (response['estado'] == 'ACTIVO') {
          String rolUsuario = response['rol'] ?? 'OPERARIO';
          String nombreUsuario = response['operario'] ?? 'OPERARIO';

          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userNombre', nombreUsuario);
          await prefs.setString('userRol', rolUsuario);

          if (!kIsWeb) {
            await DescargaSincronizada().descargarTodoDesdeSupabase(rol: rolUsuario);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MenuPage()),
            );
          }
        } else {
          _mostrarError("Usuario inactivo. Consulte al administrador.");
        }
      } else {
        _mostrarError("Credenciales inválidas.");
      }
    } catch (e) {
      _mostrarError("Error al conectar: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: Image.asset(
                'assets/logo/logo.png',
                height: 24,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.code_rounded,
                  size: 20,
                  color: Colors.black26,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Image.asset(
                      'assets/logo/logo_cuartel.png',
                      height: 135,
                      errorBuilder: (c, e, s) => Icon(
                        Icons.shield_rounded,
                        size: 90,
                        color: _appleBlue,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      "SISTEMA DE CHECK-LIST VEHICULAR",
                      style: GoogleFonts.montserrat(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "BOMBEROS VOLUNTARIOS CHIMPAY",
                      style: GoogleFonts.montserrat(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 35),
                    _buildTextField(_correoController, "Usuario / Legajo", Icons.person_outline_rounded, false),
                    const SizedBox(height: 14),
                    _buildTextField(_passController, "Contraseña", Icons.lock_outline_rounded, true),
                    const SizedBox(height: 30),
                    _isLoading
                        ? CircularProgressIndicator(color: _appleBlue)
                        : ElevatedButton(
                            onPressed: _intentarIngresar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _appleBlue,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "INGRESAR AL SISTEMA",
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _mostrarModalDevice,
                      icon: Icon(Icons.info_outline_rounded, color: _appleBlue, size: 16),
                      label: Text(
                        "Ver ID de este dispositivo",
                        style: TextStyle(
                          color: _appleBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Powered by  ",
                          style: GoogleFonts.roboto(
                            color: _textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Image.asset(
                          'assets/logo/logo.png',
                          height: 18,
                          errorBuilder: (c, e, s) => const SizedBox(),
                        ),
                        Text(
                          "   al servicio de   ",
                          style: GoogleFonts.roboto(
                            color: _textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Image.asset(
                          'assets/logo/logo_cuartel.png',
                          height: 22,
                          errorBuilder: (c, e, s) => const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "AgroSoft J&L • Versión 2026",
                      style: GoogleFonts.roboto(
                        color: _textSecondary.withOpacity(0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isPass) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _textSecondary.withOpacity(0.15), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: TextStyle(
          color: _textPrimary,
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: _textSecondary.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: _textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}