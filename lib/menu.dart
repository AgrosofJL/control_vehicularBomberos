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
  String _ultimoAcceso = 'Hoy';

  // ===========================================================================
  // PALETA DE COLORES ESTILO APPLE SOFT
  // ===========================================================================
  final Color _colorBg = const Color(0xFFF4F5F7);
  final Color _colorSurface = const Color(0xFFFFFFFF);
  final Color _colorText = const Color(0xFF1B231D);
  final Color _colorTextSecondary = const Color(0xFF6B7280);
  final Color _colorAccent = const Color(0xFF1E6B4C);
  final Color _colorAccentDark = const Color(0xFF123F2C);
  final Color _colorAccentSoft = const Color(0x141E6B4C);
  final Color _colorGoldSoft = const Color(0x1EB8862A);
  final Color _colorGoldText = const Color(0xFF8A6A1E);
  final Color _colorDanger = const Color(0xFFC0483C);
  final Color _colorBorder = const Color(0x1F000000);

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  // ACA ES LO NUEVO: Carga de sesión y registro de último acceso
  Future<void> _cargarDatosUsuario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String ultimo = prefs.getString('userUltimoAcceso') ?? 'Hoy';
    
    setState(() {
      _nombreUsuario = prefs.getString('userNombre') ?? 'OPERARIO';
      _rolUsuario = (prefs.getString('userRol') ?? 'OPERARIO').toUpperCase();
      _ultimoAcceso = ultimo;
    });

    // Guardar timestamp para accesos posteriores
    final DateTime ahora = DateTime.now();
    final String fechaAccesoFormato = 
        "${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')} hs";
    await prefs.setString('userUltimoAcceso', fechaAccesoFormato);
  }

  // ACA ES LO NUEVO: Formato exacto LUNES 05 DE ENERO DE 2026
  String _obtenerFechaFormateada() {
    final DateTime ahora = DateTime.now();
    const dias = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
    const meses = [
      'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
      'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
    ];
    
    final diaSemana = dias[ahora.weekday - 1];
    final diaNum = ahora.day.toString().padLeft(2, '0');
    final mes = meses[ahora.month - 1];
    return "$diaSemana $diaNum DE $mes DE ${ahora.year}";
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
            // Marca de agua institucional de fondo
            Center(
              child: Opacity(
                opacity: 0.05,
                child: Image.asset(
                  'assets/logo/logo_cuartel.png',
                  width: MediaQuery.of(context).size.width * 0.75,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Icon(
                    Icons.shield_rounded,
                    size: 180,
                    color: _colorAccent.withOpacity(0.2),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // =============================================================
                // MARCO SUPERIOR: Logo 3x3, Sincronización a la derecha
                // =============================================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: _colorSurface.withOpacity(0.95),
                    border: Border(bottom: BorderSide(color: _colorBorder, width: 1.0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo institucional embebido 3x3 en la esquina superior izquierda
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _colorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _colorBorder, width: 1.0),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/logo/logo_cuartel.png',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Icon(
                                  Icons.shield_rounded,
                                  color: _colorAccent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "BOMBEROS CHIMPAY",
                                style: GoogleFonts.roboto(
                                  color: _colorText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                "GESTIÓN VEHICULAR",
                                style: GoogleFonts.roboto(
                                  color: _colorAccent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Botón Sincronizar en la esquina superior derecha
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _colorSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _colorBorder, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync_rounded, color: _colorAccent, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        "SINCRONIZAR",
                                        style: GoogleFonts.roboto(
                                          color: _colorTextSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
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

                // =============================================================
                // BARRA DE ESTADO: Ícono persona a la izquierda y fecha a la derecha
                // =============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Lado izquierdo: Persona con "tu ultimo acceso fue..."
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _colorAccentSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_rounded, size: 14, color: _colorAccent),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "tu ultimo acceso fue $_ultimoAcceso",
                                style: GoogleFonts.roboto(
                                  color: _colorTextSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lado derecho: Formato exacto LUNES 05 DE ENERO DE 2026
                      Text(
                        _obtenerFechaFormateada(),
                        style: GoogleFonts.roboto(
                          color: _colorText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // INSIGNIA DE USUARIO / ROL
                // =============================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _colorSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _colorBorder, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Operario: $_nombreUsuario",
                          style: GoogleFonts.roboto(
                            color: _colorText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // GRILLA DE ACCIONES PRINCIPALES
                // =============================================================
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(20),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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
                        bgIcono: const Color(0x1A2FB344),
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

                // =============================================================
                // PIE DE PÁGINA INSTITUCIONAL
                // =============================================================
                Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: Text(
                    "CONTROL VEHICULAR BOMBEROS • 2026 - POWERED By Agrosoft J&L",
                    style: GoogleFonts.roboto(
                      color: _colorTextSecondary.withOpacity(0.5),
                      fontSize: 9.5,
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

  // ACA ES LO NUEVO: Tarjetas estilo Apple Soft con sombreado y bordes cruzados al pulsar
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
        borderRadius: BorderRadius.circular(22),
        splashColor: const Color(0xFFFFFDE7),
        highlightColor: const Color(0xFFFBC02D).withOpacity(0.20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _colorSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _colorBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141E18).withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgIcono,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icono, color: colorIcono, size: 25),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.roboto(
                      color: _colorText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: _colorTextSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
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