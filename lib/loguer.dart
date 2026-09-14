// ESTO LO MODIFIQUE
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  String _deviceIdentifier = "Obteniendo...";

  final Color _bgWhite = const Color(0xFFFFFFFF);
  final Color _inputBackground = const Color(0xFFF1F5F9);
  final Color _appleBlue = const Color(0xFF007AFF);
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);

  bool get _esWebOEscritorio {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _obtenerDispositivo();
    _verificarSesionExistente();
  }

  Future<void> _obtenerDispositivo() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() => _deviceIdentifier = "Navegador Web / PWA");
      return;
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!mounted) return;
      setState(() => _deviceIdentifier = "Estación de Trabajo / PC");
      return;
    }

    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "Dispositivo no reconocido";

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "Dispositivo iOS";
      }
    } catch (_) {
      deviceId = "Dispositivo móvil genérico";
    }

    if (!mounted) return;
    setState(() => _deviceIdentifier = deviceId);
  }

  Future<void> _verificarSesionExistente() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (loggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuPage()),
      );
    }
  }

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
              "ID DEL DISPOSITIVO",
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
              _esWebOEscritorio
                  ? "Entorno Web / Safari detectado. Acceso libre sin restricción de hardware."
                  : "Este equipo móvil debe estar registrado en Supabase para operar.",
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
                _deviceIdentifier,
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
          if (!_esWebOEscritorio)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _appleBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _deviceIdentifier));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ ID COPIADO CORRECTAMENTE"),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                "COPIAR ID",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  // ESTO LO MODIFIQUE
  Future<void> _intentarIngresar() async {
    if (_correoController.text.trim().isEmpty || _passController.text.trim().isEmpty) {
      _mostrarError("Completá tu usuario y contraseña");
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final dbHelper = DatabaseHelper();
    final String inputUser = _correoController.text.trim();
    final String inputPass = _passController.text.trim();

    try {
      // 1. Buscar primero en Supabase
      final response = await supabase
          .from('usuarios')
          .select()
          .or('correo.ilike.$inputUser,operario.ilike.$inputUser')
          .eq('pass', inputPass)
          .maybeSingle();

      if (response != null) {
        final String dbEstado = (response['estado'] ?? '').toString().toUpperCase();

        if (dbEstado != 'ACTIVO') {
          if (mounted) setState(() => _isLoading = false);
          _mostrarError("Usuario inactivo. Consulte al administrador.");
          return;
        }

        // Control de dispositivo en móviles nativos (se omite en Web)
        final String dbDevice = (response['device'] ?? '').toString().trim();
        if (!_esWebOEscritorio && dbDevice.isNotEmpty && dbDevice != _deviceIdentifier) {
          if (mounted) setState(() => _isLoading = false);
          _mostrarError("Dispositivo móvil no autorizado.");
          return;
        }

        // 2. ACA ES LO NUEVO: Insertar en SQLite para permanencia y respaldo offline
        try {
          final localDb = await dbHelper.db;
          await localDb.insert(
            'usuarios',
            {
              'id': int.tryParse(response['id'].toString()) ?? 1,
              'correo': response['correo'] ?? response['usuario'] ?? inputUser,
              'operario': response['operario'] ?? 'OPERARIO',
              'device': response['device'] ?? '',
              'pass': response['pass'] ?? inputPass,
              'estado': dbEstado,
              'rol': response['rol'] ?? 'OPERARIO',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (sqliteError) {
          debugPrint("Aviso al guardar respaldo SQLite: $sqliteError");
        }

        // 3. Guardar sesión permanente en SharedPreferences
        final String rolUsuario = (response['rol'] ?? 'OPERARIO').toString().toUpperCase();
        final String nombreUsuario = (response['operario'] ?? 'OPERARIO').toString();

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userNombre', nombreUsuario);
        await prefs.setString('userRol', rolUsuario);

        // 4. Sincronización de catálogos
        await DescargaSincronizada().descargarTodoDesdeSupabase(rol: rolUsuario);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuPage()),
          );
        }
        return;
      } else {
        // Fallback local: Si Supabase no encuentra o no hay internet, verificar respaldo offline
        await _intentarLoginOffline(inputUser, inputPass);
      }
    } catch (e) {
      debugPrint("Fallo al conectar con Supabase, verificando local: $e");
      await _intentarLoginOffline(inputUser, inputPass);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ACA ES LO NUEVO: Consulta de respaldo sobre SQLite cuando no hay red
  Future<void> _intentarLoginOffline(String inputUser, String inputPass) async {
    try {
      final dbHelper = DatabaseHelper();
      final localDb = await dbHelper.db;
      
      final List<Map<String, dynamic>> res = await localDb.query(
        'usuarios',
        where: '(UPPER(correo) = ? OR UPPER(operario) = ?) AND pass = ?',
        whereArgs: [inputUser.toUpperCase(), inputUser.toUpperCase(), inputPass],
      );

      if (res.isNotEmpty) {
        final usuarioLocal = res.first;
        final String estadoLocal = (usuarioLocal['estado'] ?? '').toString().toUpperCase();

        if (estadoLocal != 'ACTIVO') {
          _mostrarError("Usuario inactivo en registro local.");
          return;
        }

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userNombre', usuarioLocal['operario'] ?? 'OPERARIO');
        await prefs.setString('userRol', (usuarioLocal['rol'] ?? 'OPERARIO').toString().toUpperCase());

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuPage()),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint("Error en validación offline: $e");
    }

    _mostrarError("Credenciales inválidas o sin acceso.");
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