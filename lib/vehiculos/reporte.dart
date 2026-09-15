// ESTO LO MODIFIQUE
// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../base.dart'; 
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportesPage extends StatefulWidget {
  final String userRol;    
  final String userNombre; 

  const ReportesPage({super.key, required this.userRol, required this.userNombre});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _filtroPeriodo = 'TODOS'; 
  String _filtroTipo = 'TODOS';    
  List<Map<String, dynamic>> _auditoriasCabecera = [];
  bool _isLoading = false;

  String _mesSeleccionado = 'TODOS';
  final List<Map<String, String>> _mesesAnio = [
    {'valor': 'TODOS', 'nombre': 'TODOS LOS MESES'},
    {'valor': '01', 'nombre': 'ENERO'},
    {'valor': '02', 'nombre': 'FEBRERO'},
    {'valor': '03', 'nombre': 'MARZO'},
    {'valor': '04', 'nombre': 'ABRIL'},
    {'valor': '05', 'nombre': 'MAYO'},
    {'valor': '06', 'nombre': 'JUNIO'},
    {'valor': '07', 'nombre': 'JULIO'},
    {'valor': '08', 'nombre': 'AGOSTO'},
    {'valor': '09', 'nombre': 'SEPTIEMBRE'},
    {'valor': '10', 'nombre': 'OCTUBRE'},
    {'valor': '11', 'nombre': 'NOVIEMBRE'},
    {'valor': '12', 'nombre': 'DICIEMBRE'},
  ];

  final Color _colorBg = const Color(0xFFF3F5F1);
  final Color _colorSurface = const Color(0xFFFFFFFF);
  final Color _colorText = const Color(0xFF1B231D);
  final Color _colorTextSecondary = const Color(0xFF5F6B62);
  final Color _colorAccent = const Color(0xFF1E6B4C);
  final Color _colorAccentDark = const Color(0xFF123F2C);
  final Color _colorAccentSoft = const Color(0x1A1E6B4C); 
  final Color _colorBorder = const Color(0x1A1B231D);     

  @override
  void initState() {
    super.initState();
    _cargarHistorialReportes();
  }

  // ACA ES LO NUEVO: Consulta adaptada a Supabase directo en Web para evitar crasheos de SQLite
  Future<void> _cargarHistorialReportes() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> lista = [];

      if (kIsWeb) {
        var query = Supabase.instance.client
            .from('chequeos_vehicular')
            .select();

        if (widget.userRol.toUpperCase() != 'ADMIN') {
          query = query.ilike('inspecciono', widget.userNombre.trim());
        }

        final res = await query.order('fecha', ascending: false);

        // Agrupamos en memoria por reg_local para obtener cabeceras únicas sin subqueries rotas
        Map<String, Map<String, dynamic>> agrupados = {};
        for (var fila in res) {
          String reg = fila['reg_local']?.toString() ?? fila['id'].toString();
          if (!agrupados.containsKey(reg)) {
            agrupados[reg] = Map<String, dynamic>.from(fila);
          }
        }
        lista = agrupados.values.toList();
      } else {
        final db = await _dbHelper.db;
        String query = '''
          SELECT id, interno, dominio, marca, unidad, tipo_unidad, fecha, utilizado_por, inspecciono, obra_base, reg_local, fecha_vto,
                 tarjeta_verde, comprobante_patente, comprobante_seguro, cedula_transporte, verificacion_tec, doc_chofer,
                 MIN(estado) as estado_global
          FROM chequeos_vehicular WHERE 1=1
        ''';

        if (widget.userRol.toUpperCase() != 'ADMIN') {
          query += " AND UPPER(inspecciono) = '${widget.userNombre.toUpperCase()}'";
        }

        query += " GROUP BY reg_local ORDER BY fecha DESC, id DESC";
        lista = await db.rawQuery(query);
      }

      // Filtros de fecha en memoria
      final String fechaHoy = DateTime.now().toString().substring(0, 10);
      final String hace7Dias = DateTime.now().subtract(const Duration(days: 7)).toString().substring(0, 10);
      final String hace30Dias = DateTime.now().subtract(const Duration(days: 30)).toString().substring(0, 10);

      List<Map<String, dynamic>> filtrados = lista.where((item) {
        String fecha = (item['fecha'] ?? '').toString();
        if (_filtroPeriodo == 'HOY' && fecha != fechaHoy) return false;
        if (_filtroPeriodo == 'SEMANA' && fecha.compareTo(hace7Dias) < 0) return false;
        if (_filtroPeriodo == 'MES' && fecha.compareTo(hace30Dias) < 0) return false;

        if (_mesSeleccionado != 'TODOS') {
          if (fecha.length >= 7) {
            String mes = fecha.substring(5, 7);
            if (mes != _mesSeleccionado) return false;
          } else {
            return false;
          }
        }

        if (_filtroTipo == 'PESADO') {
          return (item['tipo_unidad'] ?? '').toString().toUpperCase() == 'PESADO';
        } else if (_filtroTipo == 'OTROS') {
          return (item['tipo_unidad'] ?? '').toString().toUpperCase() != 'PESADO';
        }

        return true;
      }).toList();

      setState(() {
        _auditoriasCabecera = filtrados;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      setState(() => _isLoading = false);
    }
  }

  // ACA ES LO NUEVO: Carga de ítems para PDF compatible con Web y Móvil
  Future<pw.Document> _construirDocumentoPdf(String regLocal, Map<String, dynamic> cabecera) async {
    List<Map<String, dynamic>> items = [];

    if (kIsWeb) {
      final res = await Supabase.instance.client
          .from('chequeos_vehicular')
          .select()
          .eq('reg_local', regLocal)
          .order('id', ascending: true);
      items = List<Map<String, dynamic>>.from(res);
    } else {
      final db = await _dbHelper.db;
      items = await db.query(
        'chequeos_vehicular', 
        where: 'reg_local = ?', 
        whereArgs: [regLocal], 
        orderBy: 'id ASC'
      );
    }

    final pdf = pw.Document();
    
    final List<Map<String, dynamic>> colIzquierda = [];
    final List<Map<String, dynamic>> colDerecha = [];

    for (int i = 0; i < items.length; i++) {
      if (i < 28) {
        colIzquierda.add(items[i]);
      } else {
        colDerecha.add(items[i]);
      }
    }

    String visualMapRaw = '';
    String observacionesTxt = '';
    if (items.isNotEmpty) {
      visualMapRaw = items.first['visual_map'] ?? '';
      observacionesTxt = items.first['observaciones'] ?? '';
    }

    Uint8List logoCuartelBytes = Uint8List(0);
    try {
      final ByteData data = await rootBundle.load('assets/logo/logo_cuartel.png');
      logoCuartelBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint("Aviso al cargar logo en PDF: $e");
    }

    // HOJA 1
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          const PdfColor azulInstitucional = PdfColor.fromInt(0xFF1E6B4C);
          const PdfColor azulOscuro = PdfColor.fromInt(0xFF123F2C);
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "ASOCIACIÓN BOMBEROS VOLUNTARIOS DE CHIMPAY (R.N.)",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azulOscuro),
                      ),
                      pw.Text(
                        "CHECK LIST VEHICULAR - CÉDULA OPERATIVA PATRIMONIAL",
                        style: pw.TextStyle(fontSize: 8, color: azulInstitucional, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "REGISTRO CENTRALIZADO DE HISTORIAL DE CONTROL",
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  logoCuartelBytes.isNotEmpty 
                      ? pw.Image(pw.MemoryImage(logoCuartelBytes), width: 75, height: 75)
                      : pw.SizedBox(width: 75, height: 75),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.5, color: azulInstitucional),
              pw.SizedBox(height: 4),

              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100, 
                  border: pw.Border(left: pw.BorderSide(color: azulInstitucional, width: 3)),
                ),
                child: pw.Text(
                  "DECLARACIÓN JURADA DE ACTIVOS: El presente instrumento legal certifica la existencia, estado de conservación operativa y control de seguridad correspondiente a la unidad móvil de la dotación declarada.",
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Fecha de Auditoría: ${cabecera['fecha']}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Móvil Interno: INT ${(cabecera['interno'] ?? '-').toString().split('.')[0]}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: azulInstitucional))),
                    ]
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Marca / Modelo: ${cabecera['marca']}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Dominio Patente: ${cabecera['dominio']}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    ]
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Conductor Designado: ${cabecera['utilizado_por'] ?? '-'}", style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Destino / Obra Base: ${cabecera['obra_base'] ?? '-'}", style: const pw.TextStyle(fontSize: 7))),
                    ]
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Inspeccionó Control: ${cabecera['inspecciono']}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Vto. Matafuego: ${cabecera['fecha_vto'] ?? '-'}", style: pw.TextStyle(fontSize: 7, color: PdfColors.red900, fontWeight: pw.FontWeight.bold))),
                    ]
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("Tarjeta Verde: ${cabecera['tarjeta_verde'] ?? 'SI'}", style: const pw.TextStyle(fontSize: 6.5))),
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("Comprobante Patente: ${cabecera['comprobante_patente'] ?? 'SI'}", style: const pw.TextStyle(fontSize: 6.5))),
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("Comprobante Seguro: ${cabecera['comprobante_seguro'] ?? 'SI'}", style: const pw.TextStyle(fontSize: 6.5))),
                    ]
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("Cédula Transporte: ${cabecera['cedula_transporte'] ?? 'NA'}", style: const pw.TextStyle(fontSize: 6.5))),
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("VTI Verificación: ${cabecera['verificacion_tec'] ?? 'SI'}", style: const pw.TextStyle(fontSize: 6.5))),
                      pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4), child: pw.Text("Doc. Chofer: ${cabecera['doc_chofer'] ?? 'SI'}", style: const pw.TextStyle(fontSize: 6.5))),
                    ]
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("ÍTEM", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("DESCRIPCIÓN DEL ÍTEM", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("ESTADO", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("CONTROL", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          ]
                        ),
                        ...colIzquierda.map((it) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text("${colIzquierda.indexOf(it) + 1}", style: const pw.TextStyle(fontSize: 5.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(it['item'] ?? '', style: const pw.TextStyle(fontSize: 5.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(it['estado'] ?? 'B', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: azulInstitucional), textAlign: pw.TextAlign.center)),
                              pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(it['control'] ?? '', style: const pw.TextStyle(fontSize: 5.5), textAlign: pw.TextAlign.left)),
                            ]
                          );
                        }),
                      ]
                    ),
                  ),
                  pw.SizedBox(width: 6),

                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("ÍTEM", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("DESCRIPCIÓN DEL ÍTEM", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("ESTADO", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                            pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("CONTROL", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          ]
                        ),
                        ...colDerecha.map((it) {
                          int numItem = colIzquierda.length + colDerecha.indexOf(it) + 1;
                          bool esDivisorCamion = numItem == 46 && cabecera['tipo_unidad'].toString().toUpperCase() == 'PESADO';
                          PdfColor? fondoCelda = esDivisorCamion ? PdfColors.amber100 : null;

                          return pw.TableRow(
                            children: [
                              pw.Container(color: fondoCelda, padding: const pw.EdgeInsets.all(2.5), child: pw.Text("$numItem", style: const pw.TextStyle(fontSize: 5.5))),
                              pw.Container(color: fondoCelda, padding: const pw.EdgeInsets.all(2.5), child: pw.Text(esDivisorCamion ? "PESADOS - ${it['item']}" : (it['item'] ?? ''), style: const pw.TextStyle(fontSize: 5.5))),
                              pw.Container(color: fondoCelda, padding: const pw.EdgeInsets.all(2.5), child: pw.Text(it['estado'] ?? 'B', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: azulInstitucional), textAlign: pw.TextAlign.center)),
                              pw.Container(color: fondoCelda, padding: const pw.EdgeInsets.all(2.5), child: pw.Text(it['control'] ?? '', style: const pw.TextStyle(fontSize: 5.5), textAlign: pw.TextAlign.left)),
                            ]
                          );
                        }),
                      ]
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Página 1 de 2 - Control de Matriz Operativa", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
              )
            ],
          );
        },
      ),
    );

    // HOJA 2
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          const PdfColor azulInstitucional = PdfColor.fromInt(0xFF1E6B4C);
          var labelStyle = pw.TextStyle(fontSize: 6.5, color: azulInstitucional, fontWeight: pw.FontWeight.bold);
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "ANEXO DE DAÑOS Y NOVEDADES - INT ${(cabecera['interno'] ?? '-').toString().split('.')[0]}",
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azulInstitucional),
                  ),
                  pw.Text("Fecha: ${cabecera['fecha']}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                ]
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              pw.Text("ANEXO 4 - OBSERVACIONES GENERALES Y REQUERIMIENTOS DE MANTENIMIENTO", style: labelStyle),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                height: 120,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  observacionesTxt.isNotEmpty ? observacionesTxt.toUpperCase() : "SIN OBSERVACIONES REGISTRADAS POR EL PERSONAL DE GUARDIA.",
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900, height: 1.3),
                ),
              ),
              
              pw.SizedBox(height: 140),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 220,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1.0))
                    ),
                    padding: const pw.EdgeInsets.only(top: 6),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          (cabecera['inspecciono'] ?? 'OPERARIO LOGUEADO').toString().toUpperCase(), 
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: azulInstitucional)
                        ),
                        pw.Text("Firma del Inspector a Cargo", style: const pw.TextStyle(fontSize: 7)),
                        pw.Text("Validación del Sistema • AgroSoft J&L", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600)),
                      ]
                    )
                  ),
                ]
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Documento de Control Emitido desde Dispositivo Homologado - AgroSoft J&L 2026", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                  pw.Text("Página 2 de 2 - Folio Técnico de Cierre", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
                ]
              )
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _previsualizarEImprimirPdf(String regLocal, Map<String, dynamic> cabecera) async {
    final pdf = await _construirDocumentoPdf(regLocal, cabecera);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _compartirPdfDirecto(String regLocal, Map<String, dynamic> cabecera) async {
    final pdf = await _construirDocumentoPdf(regLocal, cabecera);
    final Uint8List bytes = await pdf.save();
    
    String internoSanitizado = (cabecera['interno'] ?? '-').toString().split('.')[0].trim();
    String fechaSanitizada = (cabecera['fecha'] ?? '').toString().replaceAll('-', '');
    
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Auditoria_INT_${internoSanitizado}_$fechaSanitizada.pdf',
    );
  }

  void _mostrarOpcionesExportacion(String regLocal, Map<String, dynamic> cabecera) {
    String internoSanitizado = (cabecera['interno'] ?? '-').toString().split('.')[0].trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: _colorSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _colorBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "REPORTE DE AUDITORÍA",
                style: GoogleFonts.roboto(
                  color: _colorTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Móvil INT $internoSanitizado • ${cabecera['fecha']}",
                style: GoogleFonts.roboto(
                  color: _colorText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: _colorBorder, thickness: 1.0, height: 1),
              const SizedBox(height: 10),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _compartirPdfDirecto(regLocal, cabecera);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _colorAccentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _colorAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Compartir Documento PDF",
                                style: GoogleFonts.roboto(
                                  color: _colorText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Enviar por WhatsApp, Correo, Drive o Telegram",
                                style: GoogleFonts.roboto(
                                  color: _colorTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: _colorAccentDark, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _previsualizarEImprimirPdf(regLocal, cabecera);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _colorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _colorBorder, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _colorSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _colorBorder, width: 1.0),
                          ),
                          child: Icon(Icons.print_rounded, color: _colorTextSecondary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Vista previa e Imprimir",
                                style: GoogleFonts.roboto(
                                  color: _colorText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Ver folio antes de imprimir o guardar en disco",
                                style: GoogleFonts.roboto(
                                  color: _colorTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: _colorTextSecondary, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          "HISTORIAL DE REPORTES", 
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: ['HOY', 'SEMANA', 'MES', 'TODOS'].map((per) {
                final bool activo = _filtroPeriodo == per;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _filtroPeriodo = per);
                          _cargarHistorialReportes();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: activo ? _colorAccent : _colorSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: activo ? _colorAccent : _colorBorder,
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            per,
                            style: GoogleFonts.roboto(
                              color: activo ? Colors.white : _colorTextSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23.0, vertical: 6.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: _colorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _colorBorder, width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  dropdownColor: _colorSurface,
                  value: _mesSeleccionado,
                  icon: Icon(Icons.calendar_month_rounded, color: _colorAccent, size: 18),
                  style: GoogleFonts.roboto(
                    color: _colorText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "FILTRAR POR PERIODO MENSUAL",
                    hintStyle: GoogleFonts.roboto(color: _colorTextSecondary, fontSize: 11),
                  ),
                  items: _mesesAnio.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['valor'],
                      child: Text(m['nombre']!, style: const TextStyle(letterSpacing: 0.5)),
                    );
                  }).toList(),
                  onChanged: (nuevoMes) {
                    setState(() {
                      _mesSeleccionado = nuevoMes ?? 'TODOS';
                    });
                    _cargarHistorialReportes();
                  },
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _colorAccent))
                : _auditoriasCabecera.isEmpty
                    ? Center(
                        child: Text(
                          "SIN REGISTROS PARA ESTE PERÍODO",
                          style: GoogleFonts.roboto(
                            color: _colorTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _auditoriasCabecera.length,
                        itemBuilder: (context, index) {
                          final cab = _auditoriasCabecera[index];
                          
                          String internoRaw = (cab['interno'] ?? '-').toString();
                          String internoSanitizado = internoRaw.split('.')[0].trim();
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _colorSurface, 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: _colorBorder, width: 1.2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Contenedor de imagen seguro con fallback de icono
                                  Container(
                                    width: 80, 
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: _colorBg, 
                                      borderRadius: BorderRadius.circular(14), 
                                      border: Border.all(color: _colorBorder, width: 1.0),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Center(
                                        child: Icon(
                                          Icons.fire_truck_rounded,
                                          color: _colorAccent.withOpacity(0.4),
                                          size: 34,
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
                                            Text(
                                              cab['fecha'] ?? '', 
                                              style: GoogleFonts.roboto(
                                                color: _colorTextSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "${cab['marca']} - ${cab['unidad']}", 
                                          style: GoogleFonts.roboto(
                                            color: _colorText,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "DOMINIO: ${cab['dominio']}", 
                                          style: GoogleFonts.roboto(
                                            color: _colorTextSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _mostrarOpcionesExportacion(cab['reg_local'], cab),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: _colorAccent,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "EXPORTAR / COMPARTIR", 
                                                    style: GoogleFonts.roboto(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}