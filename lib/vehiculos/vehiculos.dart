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

  final Color _colorBg = const Color(0xFFF3F5F1);
  final Color _colorSurface = const Color(0xFFFFFFFF);
  final Color _colorText = const Color(0xFF1B231D);
  final Color _colorTextSecondary = const Color(0xFF5F6B62);
  final Color _colorAccent = const Color(0xFF1E6B4C);
  final Color _colorAccentDark = const Color(0xFF123F2C);
  final Color _colorAccentSoft = const Color(0x1A1E6B4C);
  final Color _colorBorder = const Color(0x1A1B231D);
  final Color _colorOperativo = const Color(0xFF2FB344);
  final Color _colorNoOperativo = const Color(0xFFC0483C);

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
  }

  Future<void> _cargarVehiculos() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> lista = [];

      if (kIsWeb) {
        // En Web consulta Supabase directo para evitar problemas con subqueries WASM
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
          _vehiculos = lista.where((v) => (v['tipo_unidad'] ?? '').toString().toUpperCase() == 'PESADO').toList();
        } else {
          _vehiculos = lista.where((v) => (v['tipo_unidad'] ?? '').toString().toUpperCase() != 'PESADO').toList();
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
        backgroundColor: _colorSurface.withOpacity(0.92),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _colorBorder, height: 1.0),
        ),
        title: Text(
          "CENTRAL OPERATIVA",
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                _buildFilterButton('TODOS'),
                const SizedBox(width: 8),
                _buildFilterButton('PESADO'),
                const SizedBox(width: 8),
                _buildFilterButton('OTROS'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _colorAccent))
                : _vehiculos.isEmpty
                    ? Center(
                        child: Text(
                          "NO SE ENCONTRARON UNIDADES",
                          style: GoogleFonts.roboto(
                            color: _colorTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _colorAccent : _colorSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _colorAccent : _colorBorder,
                width: 1.2,
              ),
            ),
            child: Text(
              tipo,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: isSelected ? Colors.white : _colorTextSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehiculoCard(Map<String, dynamic> vehiculo) {
    String estado = (vehiculo['estado'] ?? 'ACTIVO').toString().toUpperCase();
    bool isOperativo = estado == 'OPERATIVO' || estado == 'B' || estado == 'ACTIVO';
    String estadoVisual = isOperativo ? 'OPERATIVO' : 'NO OPERATIVO';
    String internoSanitizado = (vehiculo['interno'] ?? '-').toString().split('.')[0].trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _colorSurface, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colorBorder, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _colorBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _colorBorder, width: 1.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/catalogo/catalogo/$internoSanitizado.png',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Center(
                        child: Icon(
                          Icons.fire_truck_rounded,
                          color: _colorAccent.withOpacity(0.4),
                          size: 30,
                        ),
                      ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _colorAccentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "INT $internoSanitizado",
                              style: GoogleFonts.roboto(
                                color: _colorAccentDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isOperativo ? _colorOperativo : _colorNoOperativo).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              estadoVisual,
                              style: GoogleFonts.roboto(
                                color: isOperativo ? const Color(0xFF1E7E34) : _colorNoOperativo,
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
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "DOMINIO: ${vehiculo['dominio'] ?? '-'}",
                        style: GoogleFonts.roboto(
                          color: _colorTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChequeosPage(vehiculoSeleccionado: vehiculo),
                          ),
                        ).then((_) => _cargarVehiculos()); 
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _colorAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              "NUEVO CHEQUEO",
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}