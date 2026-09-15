// ESTO LO MODIFIQUE
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
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

  // ===========================================================================
  // PALETA APPLE SOFT LIGHT - FORMATO INSTITUCIONAL CSS
  // ===========================================================================
  final Color _colorBg = const Color(0xFFF3F5F1);
  final Color _colorSurface = const Color(0xFFFFFFFF);
  final Color _colorText = const Color(0xFF1B231D);
  final Color _colorTextSecondary = const Color(0xFF5F6B62);
  final Color _colorAccent = const Color(0xFF1E6B4C);
  final Color _colorAccentDark = const Color(0xFF123F2C);
  final Color _colorAccentSoft = const Color(0x1A1E6B4C); 
  final Color _colorGoldSoft = const Color(0x24B8862A);   
  final Color _colorGoldText = const Color(0xFF8A6A1E);
  final Color _colorBorder = const Color(0x1A1B231D);     

  @override
  void initState() {
    super.initState();
    _cargarHistorialReportes();
  }

  Future<void> _cargarHistorialReportes() async {
    setState(() => _isLoading = true);
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

    final String fechaHoy = DateTime.now().toString().substring(0, 10);
    if (_filtroPeriodo == 'HOY') {
      query += " AND fecha = '$fechaHoy'";
    } else if (_filtroPeriodo == 'SEMANA') {
      query += " AND fecha >= '${DateTime.now().subtract(const Duration(days: 7)).toString().substring(0, 10)}'";
    } else if (_filtroPeriodo == 'MES') {
      query += " AND fecha >= '${DateTime.now().subtract(const Duration(days: 30)).toString().substring(0, 10)}'";
    }

    if (_mesSeleccionado != 'TODOS') {
      query += " AND substr(fecha, 6, 2) = '$_mesSeleccionado'";
    }

    query += " GROUP BY reg_local ORDER BY fecha DESC, id DESC";
    final List<Map<String, dynamic>> res = await db.rawQuery(query);

    setState(() {
      if (_filtroTipo == 'TODOS') {
        _auditoriasCabecera = res;
      } else if (_filtroTipo == 'PESADO') {
        _auditoriasCabecera = res.where((v) => (v['tipo_unidad'] ?? '').toString().toUpperCase() == 'PESADO').toList();
      } else if (_filtroTipo == 'OTROS') {
        _auditoriasCabecera = res.where((v) => (v['tipo_unidad'] ?? '').toString().toUpperCase() != 'PESADO').toList();
      }
      _isLoading = false;
    });
  }

  // ===========================================================================
  // CONSTRUCTOR DEL DOCUMENTO PDF ESTRUCTURAL (2 PÁGINAS)
  // ===========================================================================
  Future<pw.Document> _construirDocumentoPdf(String regLocal, Map<String, dynamic> cabecera) async {
    final db = await _dbHelper.db;
    
    final List<Map<String, dynamic>> items = await db.query(
      'chequeos_vehicular', 
      where: 'reg_local = ?', 
      whereArgs: [regLocal], 
      orderBy: 'id ASC'
    );

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
      debugPrint("❌ Error cargando logo: $e");
    }

    Uint8List planoCatalogoBytes = Uint8List(0);
    try {
      final ByteData data = await rootBundle.load('assets/catalogo/catalogo.png');
      planoCatalogoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint("❌ Error cargando plano: $e");
    }

    // HOJA 1: Cabecera, Metadatos y Matriz Operativa Espejo
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
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100, 
                  border: const pw.Border(left: pw.BorderSide(color: azulInstitucional, width: 3)),
                ),
                child: pw.Text(
                  "DECLARACIÓN JURADA DE ACTIVOS: El presente instrumento legal certifica la existencia, estado de conservación operativa y control de seguridad correspondiente a la unidad móvil de la dotación declarada.",
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 8),

              // Tabla de Metadatos
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

              // Tabla de Documentación
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

              // Matriz de ítems dividida en 2 columnas
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

    // HOJA 2: Mapa de Daños y Firma Única
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          const PdfColor azulInstitucional = PdfColor.fromInt(0xFF1E6B4C);
          var labelStyle = pw.TextStyle(fontSize: 6.5, color: azulInstitucional, fontWeight: pw.FontWeight.bold);
          
          final double pdfWidth = 500.0;
          final double pdfHeight = 140.0;

          List<pw.Widget> stackDeDanos = [];
          if (planoCatalogoBytes.isNotEmpty) {
            stackDeDanos.add(
              pw.Center(
                child: pw.Image(pw.MemoryImage(planoCatalogoBytes), fit: pw.BoxFit.contain),
              )
            );

            if (visualMapRaw.isNotEmpty) {
              for (var puntoStr in visualMapRaw.split(';')) {
                var coords = puntoStr.split(',');
                if (coords.length == 2) {
                  double? pctX = double.tryParse(coords[0]);
                  double? pctY = double.tryParse(coords[1]);
                  if (pctX != null && pctY != null) {
                    stackDeDanos.add(
                      pw.Positioned(
                        left: (pctX * pdfWidth) - 3.5, 
                        top: (pctY * pdfHeight) - 3.5,
                        child: pw.Container(
                          width: 7,
                          height: 7,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.red700,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }
                }
              }
            }
          }

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

              pw.Text("ANEXO 3.B - MAPA REGISTRO VISUAL DE GOLPES Y RAYADURAS DETECTADAS", style: labelStyle),
              pw.SizedBox(height: 6),
              pw.Container(
                height: pdfHeight,
                width: pdfWidth,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  color: PdfColors.white,
                ),
                padding: const pw.EdgeInsets.all(8),
                child: planoCatalogoBytes.isNotEmpty 
                    ? pw.Stack(children: stackDeDanos)
                    : pw.Center(child: pw.Text("SIN NOVEDADES VISUALES REGISTRADAS", style: const pw.TextStyle(fontSize: 7))),
              ),
              pw.SizedBox(height: 20),

              pw.Text("ANEXO 4 - OBSERVACIONES GENERALES Y REQUERIMIENTOS DE MANTENIMIENTO", style: labelStyle),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                height: 80,
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
              
              pw.SizedBox(height: 100),

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

  // ===========================================================================
  // MÉTODOS DE IMPRESIÓN Y COMPARTIR NATIVO
  // ===========================================================================
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

  // ===========================================================================
  // ACA ES LO NUEVO: Cuadro de diálogo modal estilo Apple para elegir acción
  // ===========================================================================
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

              // Opción 1: Compartir PDF
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _compartirPdfDirecto(regLocal, cabecera);
                  },
                  borderRadius: BorderRadius.circular(14),
                  splashColor: const Color(0xFFFFFDE7),
                  highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
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

              // Opción 2: Previsualizar e Imprimir
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _previsualizarEImprimirPdf(regLocal, cabecera);
                  },
                  borderRadius: BorderRadius.circular(14),
                  splashColor: const Color(0xFFFFFDE7),
                  highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
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
          // Selector de periodo
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
                        splashColor: const Color(0xFFFFFDE7),
                        highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: activo ? _colorAccent : _colorSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: activo ? _colorAccent : _colorBorder,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF141E18).withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
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

          // Selector de mes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23.0, vertical: 6.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: _colorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _colorBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF141E18).withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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

          // Listado
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
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF141E18).withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
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
                                      // ESTO LO MODIFIQUE: Ruta directa limpia
child: Image.asset(
  'assets/catalogo/$internoSanitizado.png', 
  fit: BoxFit.cover,
  errorBuilder: (c, e, s) => Icon(
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
                                            splashColor: const Color(0xFFFFFDE7),
                                            highlightColor: const Color(0xFFFBC02D).withOpacity(0.2),
                                            child: Container(
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: _colorAccent,
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _colorAccent.withOpacity(0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
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