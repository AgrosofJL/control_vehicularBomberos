// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import '../base.dart'; 

class ChequeosPage extends StatefulWidget {
  final Map<String, dynamic>? vehiculoSeleccionado;

  const ChequeosPage({super.key, this.vehiculoSeleccionado});

  @override
  State<ChequeosPage> createState() => _ChequeosPageState();
}

class _ChequeosPageState extends State<ChequeosPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _internoController = TextEditingController();
  final TextEditingController _unidadController = TextEditingController();
  final TextEditingController _dominioController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _inspeccionoController = TextEditingController();
  final TextEditingController _fechaProxServiceController = TextEditingController();
  final TextEditingController _obraBaseController = TextEditingController();

  String _tarjetaVerde = 'SI';
  String _comprobantePatente = 'SI';
  String _comprobanteSeguro = 'SI';
  String _cedulaTransporte = 'NA';
  String _verificacionTec = 'SI';
  String _docChofer = 'SI';
  final TextEditingController _fechaVtoMatafuegoController = TextEditingController();

  final TextEditingController _observacionesController = TextEditingController();
  final List<Offset> _visualPoints = [];
  final double _imagenAlto = 160.0;

  String _tipoUnidad = 'OTROS'; 
  bool _isLoading = false;
  bool _vieneDesdeInventario = false;
  
  List<Map<String, dynamic>> _listaVehiculosDropdown = [];
  String? _vehiculoElegidoInterno;

  List<Map<String, dynamic>> _listaPersonalDropdown = [];
  String? _conductorSeleccionado; 

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
  final Color _colorSuccess = const Color(0xFF2FB344);
  final Color _colorSuccessSoft = const Color(0x1F2FB344);

  final List<String> _referencias = ['B', 'R', 'RV', 'C', 'NA', 'O', 'F'];
  final Map<int, Map<String, dynamic>> _respuestasItems = {}; 
  List<Map<String, dynamic>> _itemsMaestros = [];

  final Map<String, String> _guiaReferencias = {
    'B': 'Bueno',
    'R': 'Regular',
    'RV': 'Revisar',
    'C': 'Crítico',
    'NA': 'No Aplica',
    'O': 'Observado',
    'F': 'Faltante',
  };

  @override
  void initState() {
    super.initState();
    _inicializarFormulario();
    _cargarTodoElContenido();
  }

  Future<void> _cargarTodoElContenido() async {
    setState(() => _isLoading = true);
    await _cargarUnidadesExistentes();
    await _cargarItemsDesdeBD(); 
    await _cargarPersonal(); 
    await _autocompletarUsuarioLogueado(); 
    setState(() => _isLoading = false);
  }

  Future<void> _cargarPersonal() async {
    try {
      if (kIsWeb) {
        final res = await Supabase.instance.client.from('personal').select();
        setState(() => _listaPersonalDropdown = res);
      } else {
        final db = await _dbHelper.db;
        final List<Map<String, dynamic>> res = await db.query('personal');
        setState(() => _listaPersonalDropdown = res);
      }
    } catch (e) {
      debugPrint("Error cargando personal: $e");
    }
  }

  Future<void> _autocompletarUsuarioLogueado() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _inspeccionoController.text = prefs.getString('userNombre') ?? 'OPERARIO';
    });
  }

  Future<void> _cargarUnidadesExistentes() async {
    try {
      List<Map<String, dynamic>> res = [];
      if (kIsWeb) {
        res = await Supabase.instance.client.from('maquinaria').select();
      } else {
        final db = await _dbHelper.db;
        res = await db.rawQuery('''
          SELECT interno, marca_modelo, dominio_patente, tipo, estado FROM maquinaria 
          WHERE UPPER(estado) IN ('OPERATIVO', 'ACTIVO', 'HABILITADO') OR estado IS NULL OR estado = ''
        '''); 
      }
      
      setState(() {
        final seen = <String>{};
        _listaVehiculosDropdown = res.where((v) {
          final String intStr = (v['interno'] ?? '').toString();
          return intStr.isNotEmpty && seen.add(intStr);
        }).toList();
        
        if (widget.vehiculoSeleccionado != null) {
          final String internoBuscado = (widget.vehiculoSeleccionado!['interno'] ?? '').toString();
          bool existeEnCatalogo = _listaVehiculosDropdown.any((v) => (v['interno'] ?? '').toString() == internoBuscado);

          if (existeEnCatalogo) {
            _vehiculoElegidoInterno = internoBuscado;
            final maestro = _listaVehiculosDropdown.firstWhere((v) => (v['interno'] ?? '').toString() == internoBuscado);
            _internoController.text = (maestro['interno'] ?? '').toString();
            _dominioController.text = (maestro['dominio_patente'] ?? maestro['dominio'] ?? '').toString();
            _marcaController.text = (maestro['marca_modelo'] ?? maestro['marca'] ?? '').toString();
            _unidadController.text = (maestro['tipo'] ?? maestro['tipo_unidad'] ?? '').toString();
            _tipoUnidad = ((maestro['tipo'] ?? maestro['tipo_unidad'] ?? '').toString().toUpperCase() == 'PESADO') ? 'PESADO' : 'OTROS';
          }
        }
      });
    } catch (e) {
      debugPrint("Error cargando unidades: $e");
    }
  }

  Future<void> _cargarItemsDesdeBD() async {
    try {
      List<Map<String, dynamic>> res = [];
      if (kIsWeb) {
        res = await Supabase.instance.client.from('items_chequeo').select().order('item', ascending: true);
      } else {
        final db = await _dbHelper.db;
        res = await db.rawQuery('''
          SELECT item, descripcion, tipo_vehiculo 
          FROM items_chequeo 
          GROUP BY item 
          ORDER BY item ASC
        ''');
      }
      
      setState(() {
        _itemsMaestros = res.map((row) => {
          'id': row['item'] is int ? row['item'] : int.tryParse(row['item'].toString()) ?? 0,
          'desc': row['descripcion'] ?? '',
          'tipo': row['tipo_vehiculo'] ?? '',
        }).toList();

        for (var item in _itemsMaestros) {
          _respuestasItems[item['id']] = {'estado': null, 'control': ''};
        }
      });
    } catch (e) {
      debugPrint("❌ Error cargando ítems: $e");
    }
  }

  void _inicializarFormulario() {
    if (widget.vehiculoSeleccionado != null) {
      _vieneDesdeInventario = true;
      final v = widget.vehiculoSeleccionado!;
      _internoController.text = (v['interno'] ?? '').toString();
      _dominioController.text = (v['dominio'] ?? v['dominio_patente'] ?? '').toString();
      _marcaController.text = (v['marca'] ?? v['marca_modelo'] ?? '').toString();
      _unidadController.text = (v['unidad'] ?? v['tipo'] ?? v['tipo_unidad'] ?? '').toString();
      _tipoUnidad = ((v['tipo_unidad'] ?? v['tipo'] ?? '').toString().toUpperCase() == 'PESADO') ? 'PESADO' : 'OTROS';
    }
  }

  Future<void> _guardarChecklistLocal() async {
    if (!_formKey.currentState!.validate()) return;
    
    final itemsFiltrados = _itemsMaestros.where((element) {
      if (_tipoUnidad == 'PESADO') return true;
      return element['tipo'] != 'PESADO';
    }).toList();

    for (var item in itemsFiltrados) {
      if (_respuestasItems[item['id']]?['estado'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ FALTA EVALUAR EL ÍTEM NRO ${item['id']}.",
              style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
            ),
            backgroundColor: _colorDanger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          )
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String stringId = DateTime.now().millisecondsSinceEpoch.toString();
      String fechaActual = DateTime.now().toString().substring(0, 10);
      String regLocalClave = "REG_LOC_${DateTime.now().millisecondsSinceEpoch}";
      String visualMapSerializado = _visualPoints.map((p) => '${p.dx.toStringAsFixed(3)},${p.dy.toStringAsFixed(3)}').join(';');
      String observacionesTexto = _observacionesController.text.trim();

      List<Map<String, dynamic>> registros = [];
      for (var item in itemsFiltrados) {
        final resp = _respuestasItems[item['id']]!;
        registros.add({
          'id': stringId,
          'tipo_unidad': _tipoUnidad,
          'unidad': _unidadController.text.trim(), 
          'dominio': _dominioController.text.trim().toUpperCase(),   
          'marca': _marcaController.text.trim().toUpperCase(), 
          'interno': _internoController.text.trim(),
          'fecha_prox_Ser': _fechaProxServiceController.text.trim(),
          'utilizado_por': _conductorSeleccionado ?? '', 
          'inspecciono': _inspeccionoController.text.trim(),
          'tarjeta_verde': _tarjetaVerde, 
          'comprobante_patente': _comprobantePatente,
          'obra_base': _obraBaseController.text.trim(),
          'comprobante_seguro': _comprobanteSeguro,
          'cedula_transporte': _cedulaTransporte,
          'verificacion_tec': _verificacionTec,
          'doc_chofer': _docChofer,
          'item': item['desc'],
          'estado': resp['estado'], 
          'control': resp['control'], 
          'fecha': fechaActual,
          'verifico': _inspeccionoController.text.trim(),
          'fecha_vto': _fechaVtoMatafuegoController.text.trim(), 
          'reg_local': regLocalClave,
          'visual_map': visualMapSerializado,
          'observaciones': observacionesTexto,
        });
      }

      if (kIsWeb) {
        // En Safari Web se impacta directo en Supabase para evitar fallas con Workers
        await Supabase.instance.client.from('chequeos_vehicular').insert(registros);
      } else {
        final localDb = await _dbHelper.db;
        await localDb.transaction((txn) async {
          for (var reg in registros) {
            await txn.insert('chequeos_vehicular', reg);
          }
        });
      }

      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ AUDITORÍA GUARDADA CORRECTAMENTE",
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          backgroundColor: _colorAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ ERROR AL GUARDAR: $e",
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          backgroundColor: _colorDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Widget _buildFichaResumenUnidad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _colorAccentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fire_truck_rounded, color: _colorAccentDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "MÓVIL INT ${_internoController.text}",
                      style: GoogleFonts.roboto(
                        color: _colorText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _colorGoldSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _tipoUnidad,
                        style: GoogleFonts.roboto(
                          color: _colorGoldText,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "${_marcaController.text} • ${_unidadController.text} | PATENTE: ${_dominioController.text}",
                  style: GoogleFonts.roboto(
                    color: _colorTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: _colorTextSecondary.withOpacity(0.4), size: 18),
        ],
      ),
    );
  }

  Widget _buildCuadroReferencias() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colorBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _colorTextSecondary),
              const SizedBox(width: 6),
              Text(
                "GUÍA DE REFERENCIAS",
                style: GoogleFonts.roboto(
                  color: _colorTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _guiaReferencias.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key,
                      style: GoogleFonts.roboto(
                        color: _colorAccentDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "= ${e.value}",
                      style: GoogleFonts.roboto(
                        color: _colorTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _abrirModalPlanoExpandido() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog.fullscreen(
              child: Scaffold(
                backgroundColor: _colorBg,
                appBar: AppBar(
                  backgroundColor: _colorSurface,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.close_rounded, color: _colorText, size: 24),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                  title: Text(
                    "MAPA DE DAÑOS",
                    style: GoogleFonts.roboto(
                      color: _colorText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  actions: [
                    TextButton.icon(
                      onPressed: () {
                        if (_visualPoints.isNotEmpty) {
                          setModalState(() => _visualPoints.removeLast());
                          setState(() {});
                        }
                      },
                      icon: Icon(Icons.undo_rounded, size: 18, color: _colorTextSecondary),
                      label: Text("DESHACER", style: GoogleFonts.roboto(color: _colorTextSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        if (_visualPoints.isNotEmpty) {
                          setModalState(() => _visualPoints.clear());
                          setState(() {});
                        }
                      },
                      icon: Icon(Icons.delete_sweep_rounded, size: 18, color: _colorDanger),
                      label: Text("LIMPIAR", style: GoogleFonts.roboto(color: _colorDanger, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double anchoModal = constraints.maxWidth;
                            final double altoModal = constraints.maxHeight;

                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: _colorSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _colorBorder, width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTapDown: (TapDownDetails details) {
                                          double pctX = details.localPosition.dx / anchoModal;
                                          double pctY = details.localPosition.dy / altoModal;
                                          setModalState(() {
                                            _visualPoints.add(Offset(pctX, pctY));
                                          });
                                          setState(() {});
                                        },
                                        child: Container(
                                          color: _colorSurface,
                                          padding: const EdgeInsets.all(16),
                                          child: Image.asset(
                                            'assets/catalogo/catalogo.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (c, e, s) => Center(
                                              child: Text("PLANO NO DISPONIBLE", style: GoogleFonts.roboto(color: _colorTextSecondary)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    ..._visualPoints.map((Offset punto) {
                                      return Positioned(
                                        left: (punto.dx * anchoModal) - 9,
                                        top: (punto.dy * altoModal) - 9,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: _colorDanger.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.0),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(modalContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorAccent,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("LISTO (${_visualPoints.length} MARCAS)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeccionChequeoVisual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSeccionTitulo("3.B MAPA DE DAÑOS EXTERNOS"),
            TextButton.icon(
              onPressed: _abrirModalPlanoExpandido,
              icon: Icon(Icons.fullscreen_rounded, size: 16, color: _colorAccentDark),
              label: Text("EXPANDIR", style: GoogleFonts.roboto(color: _colorAccentDark, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final double widthCelular = constraints.maxWidth;

            return Container(
              height: _imagenAlto,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _colorSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colorBorder, width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          double pctX = details.localPosition.dx / widthCelular;
                          double pctY = details.localPosition.dy / _imagenAlto;
                          setState(() {
                            _visualPoints.add(Offset(pctX, pctY));
                          });
                        },
                        child: Container(
                          color: _colorSurface,
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/catalogo/catalogo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Center(
                              child: Text(
                                "PLANO NO DISPONIBLE",
                                style: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ..._visualPoints.map((Offset punto) {
                      return Positioned(
                        left: (punto.dx * widthCelular) - 6,
                        top: (punto.dy * _imagenAlto) - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _colorDanger.withOpacity(0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsFiltrados = _itemsMaestros.where((element) {
      if (_tipoUnidad == 'PESADO') return true;
      return element['tipo'] != 'PESADO';
    }).toList();

    return Scaffold(
      backgroundColor: _colorBg,
      appBar: AppBar(
        backgroundColor: _colorSurface.withOpacity(0.92),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "PLANILLA DE AUDITORÍA",
          style: GoogleFonts.roboto(color: _colorText, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colorAccent, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _colorAccent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                children: [
                  _buildSeccionTitulo("1. INFORMACIÓN DE LA UNIDAD"),
                  const SizedBox(height: 10),

                  if (_vieneDesdeInventario)
                    _buildFichaResumenUnidad()
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: _colorSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _colorBorder, width: 1.2),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: _colorSurface,
                          hint: Text("Elegir un móvil del cuartel...", style: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 13)),
                          value: _vehiculoElegidoInterno, 
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: _colorAccent),
                          items: _listaVehiculosDropdown.map((vehiculo) {
                            final String intVal = (vehiculo['interno'] ?? '').toString();
                            return DropdownMenuItem<String>(
                              value: intVal, 
                              child: Text(
                                "INT $intVal - ${vehiculo['marca_modelo'] ?? vehiculo['marca']} (${vehiculo['dominio_patente'] ?? vehiculo['dominio']})",
                                style: GoogleFonts.roboto(color: _colorText, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _vehiculoElegidoInterno = newValue;
                              if (newValue != null) {
                                final seleccionado = _listaVehiculosDropdown.firstWhere(
                                  (v) => (v['interno'] ?? '').toString() == newValue,
                                  orElse: () => {},
                                );
                                if (seleccionado.isNotEmpty) {
                                  _internoController.text = (seleccionado['interno'] ?? '').toString();
                                  _dominioController.text = (seleccionado['dominio_patente'] ?? seleccionado['dominio'] ?? '').toString();
                                  _marcaController.text = (seleccionado['marca_modelo'] ?? seleccionado['marca'] ?? '').toString();
                                  _unidadController.text = (seleccionado['tipo'] ?? seleccionado['tipo_unidad'] ?? '').toString();
                                  _tipoUnidad = (seleccionado['tipo'] ?? seleccionado['tipo_unidad'] ?? 'OTROS').toString().toUpperCase();
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_internoController, "Interno *", Icons.tag_rounded, verdadero: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_dominioController, "Patente *", Icons.badge_rounded, verdadero: true)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 22),
                  _buildSeccionTitulo("2. OPERACIÓN Y CONTROL"),
                  const SizedBox(height: 10),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: _colorSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _colorBorder, width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: _colorSurface,
                        value: _conductorSeleccionado,
                        hint: Text("Elegir Conductor *", style: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 13)),
                        items: _listaPersonalDropdown.map((p) {
                          String nombre = (p['nombre_completo'] ?? p['operario'] ?? 'Sin Nombre').toString().toUpperCase();
                          return DropdownMenuItem<String>(
                            value: nombre,
                            child: Text(nombre, style: GoogleFonts.roboto(color: _colorText, fontSize: 13, fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _conductorSeleccionado = val),
                        validator: (value) => value == null ? 'Conductor requerido' : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  _buildInput(_inspeccionoController, "Inspección a cargo de *", Icons.verified_user_outlined, verdadero: true, bloquear: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_fechaProxServiceController, "Próx Service", Icons.calendar_today_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput(_obraBaseController, "Obra / Base", Icons.business_rounded)),
                    ],
                  ),
                  const SizedBox(height: 22),

                  _buildSeccionTitulo("2.B CONTROL DE DOCUMENTACIÓN"),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _colorSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _colorBorder, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        _buildDocSelectorRow("Tarjeta Verde", _tarjetaVerde, (val) => setState(() => _tarjetaVerde = val!)),
                        _buildDocSelectorRow("Comprobante Patente", _comprobantePatente, (val) => setState(() => _comprobantePatente = val!)),
                        _buildDocSelectorRow("Comprobante Seguro", _comprobanteSeguro, (val) => setState(() => _comprobanteSeguro = val!)),
                        _buildDocSelectorRow("Cédula Transporte", _cedulaTransporte, (val) => setState(() => _cedulaTransporte = val!)),
                        _buildDocSelectorRow("Verificación Técnica", _verificacionTec, (val) => setState(() => _verificacionTec = val!)),
                        _buildDocSelectorRow("Documentación Chofer", _docChofer, (val) => setState(() => _docChofer = val!)),
                        const SizedBox(height: 6),
                        _buildInput(_fechaVtoMatafuegoController, "Vto. Matafuego", Icons.gavel_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  _buildSeccionChequeoVisual(),
                  const SizedBox(height: 20),

                  _buildSeccionTitulo("3. MATRIZ OPERATIVA (${itemsFiltrados.length} ÍTEMS)"),
                  const SizedBox(height: 10),
                  _buildCuadroReferencias(),
                  const SizedBox(height: 12),

                  ...itemsFiltrados.map((item) => _buildItemMatrizEstructuralRow(item)),
                  const SizedBox(height: 22),

                  _buildSeccionTitulo("4. OBSERVACIONES GENERALES"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _colorSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _colorBorder, width: 1.2),
                    ),
                    child: TextFormField(
                      controller: _observacionesController,
                      maxLines: 3,
                      style: GoogleFonts.roboto(color: _colorText, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Observaciones mecánicas...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: _guardarChecklistLocal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorAccent,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      "GUARDAR AUDITORÍA",
                      style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Text(
      titulo.toUpperCase(),
      style: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 11, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icono, {bool verdadero = false, bool bloquear = false}) {
    return Container(
      decoration: BoxDecoration(
        color: bloquear ? _colorBg : _colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colorBorder, width: 1.2),
      ),
      child: TextFormField(
        controller: controller,
        enabled: !bloquear, 
        style: GoogleFonts.roboto(color: _colorText, fontSize: 12.5, fontWeight: FontWeight.w700),
        validator: verdadero ? (value) => value!.isEmpty ? 'Requerido' : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 11),
          prefixIcon: Icon(icono, color: _colorAccent, size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDocSelectorRow(String titulo, String valorActual, ValueChanged<String?> alCambiar) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: GoogleFonts.roboto(color: _colorText, fontSize: 12, fontWeight: FontWeight.w700)),
          DropdownButton<String>(
            value: valorActual,
            items: ['SI', 'NO', 'NA'].map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
            onChanged: alCambiar,
          ),
        ],
      ),
    );
  }

  Widget _buildItemMatrizEstructuralRow(Map<String, dynamic> item) {
    int id = item['id'];
    String desc = item['desc'];
    String? currentEstado = _respuestasItems[id]?['estado'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentEstado != null ? _colorSuccess : _colorBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 35,
                child: Text("$id", style: GoogleFonts.roboto(color: _colorAccent, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                flex: 3,
                child: Text(desc, style: GoogleFonts.roboto(color: _colorText, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 2,
                child: DropdownButton<String>(
                  value: currentEstado,
                  hint: const Text("-"),
                  isExpanded: true,
                  items: _referencias.map((ref) => DropdownMenuItem(value: ref, child: Text(ref))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _respuestasItems[id]?['estado'] = val);
                    }
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: _respuestasItems[id]?['control'] ?? '',
            onChanged: (val) => _respuestasItems[id]?['control'] = val,
            style: GoogleFonts.roboto(fontSize: 11.5),
            decoration: const InputDecoration(hintText: "Observación..."),
          ),
        ],
      ),
    );
  }
}