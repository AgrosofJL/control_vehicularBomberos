// ESTO LO MODIFIQUE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bajar.dart';
import 'subir.dart';
import 'vehiculos/vehiculos.dart';
import 'vehiculos/chequeos.dart';
import 'vehiculos/reporte.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool _isSyncing = false;
  String _nombreUsuario = 'OPERARIO';
  String _rolUsuario = 'OPERARIO';

  final Color _colorBg = const Color(0xFFF3F5F1);
  final Color _colorSurface = const Color(0xFFFFFFFF);
  final Color _colorText = const Color(0xFF1B231D);
  final Color _colorTextSecondary = const Color(0xFF5F6B62);
  final Color _colorAccent = const Color(0xFF1E6B4C);
  final Color _colorAccentDark = const Color(0xFF123F2C);
  final Color _colorAccentSoft = const Color(0x1A1E6B4C);
  final Color _colorGoldSoft = const Color(0x24B8862A);
  final Color _colorGoldText = const Color(0xFF8A6A1E);
  final Color _colorDanger = const Color(0xFFC0483C);
  final Color _colorBorder = const Color(0x1A1B231D);

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = prefs.getString('userNombre') ?? 'OPERARIO';
      _rolUsuario = (prefs.getString('userRol') ?? 'OPERARIO').toUpperCase();
    });
  }

  // Formateador sin librerías externas para evitar fallo de 'init' en Safari Web
  String _obtenerFechaFormateada() {
    final DateTime ahora = DateTime.now();
    const dias = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
    const meses = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    
    final diaSemana = dias[ahora.weekday - 1];
    final mes = meses[ahora.month - 1];
    return "$diaSemana ${ahora.day.toString().padLeft(2, '0')} DE $mes DE ${ahora.year}";
  }

  Future<void> _sincronizarTodoElSistema() async {
    setState(() => _isSyncing = true);
    bool subidaOk = await CargaSincronizada().subirChequeosASupabase();
    bool bajadaOk = await DescargaSincronizada().descargarTodoDesdeSupabase(rol: _rolUsuario);
    setState(() => _isSyncing = false);

    if (!mounted) return;

    if (subidaOk && bajadaOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🚀 ¡SINCRO COMPLETA EN LA NUBE!",
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          backgroundColor: _colorAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ ERROR EN LA SINCRONIZACIÓN DINÁMICA.",
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          backgroundColor: _colorDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/logo/logo_cuartel.png',
                  width: MediaQuery.of(context).size.width * 0.75,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Icon(
                    Icons.local_fire_department_rounded,
                    size: 180,
                    color: _colorAccent.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: _colorSurface.withOpacity(0.92),
                    border: Border(bottom: BorderSide(color: _colorBorder, width: 1.0)),
                    boxShadow: [
                      BoxShadow(
                        color: _colorText.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _colorAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "BOMBEROS",
                            style: GoogleFonts.roboto(
                              color: _colorText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      _isSyncing
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _colorAccent,
                              ),
                            )
                          : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _sincronizarTodoElSistema,
                                borderRadius: BorderRadius.circular(14),
                                splashColor: const Color(0xFFFFFDE7),
                                highlightColor: const Color(0xFFFBC02D).withOpacity(0.25),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _colorSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _colorBorder, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync_rounded, color: _colorAccent, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "SINCRONIZAR",
                                        style: GoogleFonts.roboto(
                                          color: _colorTextSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: _colorTextSecondary),
                          const SizedBox(width: 6),
                          Text(
                            "Sesión: $_nombreUsuario",
                            style: GoogleFonts.roboto(
                              color: _colorTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colorAccentSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _rolUsuario,
                              style: GoogleFonts.roboto(
                                color: _colorAccentDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _obtenerFechaFormateada(),
                        style: GoogleFonts.roboto(
                          color: _colorTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(22),
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.88,
                    children: [
                      _buildMenuCard(
                        titulo: "NUEVO CHEQUEO",
                        subtitulo: "Iniciar inspección interna y estado de la unidad",
                        icono: Icons.checklist_rtl_rounded,
                        bgIcono: _colorAccentSoft,
                        colorIcono: _colorAccentDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VehiculosPage()),
                        ),
                      ),
                      _buildMenuCard(
                        titulo: "VER MAQUINARIAS",
                        subtitulo: "Controlar el estado general del parque automotor",
                        icono: Icons.fire_truck_rounded,
                        bgIcono: _colorGoldSoft,
                        colorIcono: _colorGoldText,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChequeosPage()),
                        ),
                      ),
                      _buildMenuCard(
                        titulo: "EXPORTAR REPORTES",
                        subtitulo: "Descargar auditorías de control en PDF",
                        icono: Icons.picture_as_pdf_rounded,
                        bgIcono: const Color(0x1F2FB344),
                        colorIcono: const Color(0xFF1E7E34),
                        onTap: () async {
                          final SharedPreferences prefs = await SharedPreferences.getInstance();
                          String nombre = prefs.getString('userNombre') ?? 'OPERARIO';
                          String rol = prefs.getString('userRol') ?? 'OPERARIO';

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportesPage(
                                userRol: rol.toUpperCase(),
                                userNombre: nombre,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "CONTROL VEHICULAR BOMBEROS • 2026",
                    style: GoogleFonts.roboto(
                      color: _colorTextSecondary.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color bgIcono,
    required Color colorIcono,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: const Color(0xFFFFFDE7),
        highlightColor: const Color(0xFFFBC02D).withOpacity(0.18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _colorSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _colorBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141E18).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bgIcono,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, color: colorIcono, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.roboto(
                      color: _colorText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitulo,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: _colorTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}