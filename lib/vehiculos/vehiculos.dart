// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../base.dart';
import 'chequeos.dart';

class VehiculosPage extends StatefulWidget {
  const VehiculosPage({super.key});

  @override
  State<VehiculosPage> createState() => _VehiculosPageState();
}

class _VehiculosPageState extends State<VehiculosPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _filtroSeleccionado = 'TODOS';
  List<Map<String, dynamic>> _vehiculos = [];
  bool _isLoading = false;

  // ===========================================================================
  // PALETA INSTITUCIONAL APPLE SOFT
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
  final Color _colorBorder = const Color(0x1A000000);
  final Color _colorOperativo = const Color(0xFF2FB344);
  final Color _colorNoOperativo = const Color(0xFFC0483C);

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
  }

  // ACA ES LO NUEVO: Carga híbrida optimizada para Web y Móvil nativo
  Future<void> _cargarVehiculos() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> lista = [];

      if (kIsWeb) {
        final res = await Supabase.instance.client
            .from('maquinaria')
            .select()
            .order('interno', ascending: true);

        lista = res.map((m) {
          return {
            'interno': m['interno'],
            'marca': m['marca_modelo'],
            'dominio': m['dominio_patente'],
            'tipo_unidad': m['tipo'],
            'estado': m['estado'] ?? 'OPERATIVO',
          };
        }).toList();
      } else {
        final db = await _dbHelper.db;
        final res = await db.query('maquinaria', orderBy: 'interno ASC');
        lista = res.map((m) {
          return {
            'interno': m['interno'],
            'marca': m['marca_modelo'],
            'dominio': m['dominio_patente'],
            'tipo_unidad': m['tipo'],
            'estado': m['estado'] ?? 'OPERATIVO',
          };
        }).toList();
      }

      setState(() {
        if (_filtroSeleccionado == 'TODOS') {
          _vehiculos = lista;
        } else if (_filtroSeleccionado == 'PESADO') {
          _vehiculos = lista
              .where((v) =>
                  (v['tipo_unidad'] ?? '').toString().toUpperCase() == 'PESADO')
              .toList();
        } else {
          _vehiculos = lista
              .where((v) =>
                  (v['tipo_unidad'] ?? '').toString().toUpperCase() != 'PESADO')
              .toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando vehículos: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorBg,
      appBar: AppBar(
        backgroundColor: _colorSurface.withOpacity(0.95),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _colorBorder, height: 1.0),
        ),
        title: Text(
          "PARQUE AUTOMOTOR",
          style: GoogleFonts.roboto(
            color: _colorText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colorAccent, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Selector de filtros segmentado estilo Apple
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _colorSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _colorBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildFilterButton('TODOS'),
                  _buildFilterButton('PESADO'),
                  _buildFilterButton('OTROS'),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _colorAccent,
                    ),
                  )
                : _vehiculos.isEmpty
                    ? Center(
                        child: Text(
                          "NO SE ENCONTRARON UNIDADES",
                          style: GoogleFonts.roboto(
                            color: _colorTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        itemCount: _vehiculos.length,
                        itemBuilder: (context, index) {
                          return _buildVehiculoCard(_vehiculos[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ACA ES LO NUEVO: Botón de filtro con feedback sombreado suave
  Widget _buildFilterButton(String tipo) {
    bool isSelected = _filtroSeleccionado == tipo;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _filtroSeleccionado = tipo);
            _cargarVehiculos();
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFFFFDE7),
          highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? _colorAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _colorAccent.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              tipo,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: isSelected ? Colors.white : _colorTextSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ACA ES LO NUEVO: Tarjeta vehicular con icono nativo y botón de acción estilizado
  Widget _buildVehiculoCard(Map<String, dynamic> vehiculo) {
    String estado = (vehiculo['estado'] ?? 'ACTIVO').toString().toUpperCase();
    bool isOperativo = estado == 'OPERATIVO' || estado == 'B' || estado == 'ACTIVO';
    String estadoVisual = isOperativo ? 'OPERATIVO' : 'NO OPERATIVO';
    String internoSanitizado = (vehiculo['interno'] ?? '-').toString().split('.')[0].trim();
    String tipoUnidad = (vehiculo['tipo_unidad'] ?? 'OTROS').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: _colorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colorBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Contenedor de icono limpio sin llamadas fallidas a imágenes inexistentes
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _colorAccentSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _colorBorder, width: 1.0),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fire_truck_rounded,
                      color: _colorAccentDark,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _colorAccentDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "INT $internoSanitizado",
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _colorGoldSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tipoUnidad,
                                  style: GoogleFonts.roboto(
                                    color: _colorGoldText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isOperativo ? _colorOperativo : _colorNoOperativo)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              estadoVisual,
                              style: GoogleFonts.roboto(
                                color: isOperativo
                                    ? const Color(0xFF1E7E34)
                                    : _colorNoOperativo,
                                fontWeight: FontWeight.w900,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${vehiculo['marca'] ?? 'SIN MARCA'}",
                        style: GoogleFonts.roboto(
                          color: _colorText,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "PATENTE: ${vehiculo['dominio'] ?? '-'}",
                        style: GoogleFonts.roboto(
                          color: _colorTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: _colorBorder, thickness: 1.0, height: 1),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChequeosPage(vehiculoSeleccionado: vehiculo),
                    ),
                  ).then((_) => _cargarVehiculos());
                },
                borderRadius: BorderRadius.circular(12),
                splashColor: const Color(0xFFFFFDE7),
                highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colorAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _colorAccent.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        "INICIAR CHECK-LIST",
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
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
    );
  }
}