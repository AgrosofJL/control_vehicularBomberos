// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return await openDatabase(
        'checklist_bomberos.db',
        version: 4,
        onCreate: _onCreate,
      );
    } else {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'checklist_bomberos.db');
      return await openDatabase(
        path,
        version: 4,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY,
        operario TEXT,
        correo TEXT,
        device TEXT,
        rol TEXT,
        pass TEXT,
        estado TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE maquinaria (
        id INTEGER PRIMARY KEY,
        interno INTEGER,
        marca_modelo TEXT,
        dominio_patente TEXT,
        numero_motor TEXT,
        numero_chasis TEXT,
        tipo_combustible TEXT,
        sistema_electrico_bateria TEXT,
        medida_neumaticos TEXT,
        presion_psi INTEGER,
        km_hs_actual REAL,
        fecha_adquisicion TEXT,
        observaciones TEXT,
        tipo TEXT,
        estado TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE personal (
        id INTEGER PRIMARY KEY,
        nro_legajo INTEGER,
        dni INTEGER,
        nombre_completo TEXT,
        grupo_sanguineo TEXT,
        afecciones TEXT,
        nro_telefono TEXT,
        tele_familiar TEXT,
        sanciones TEXT,
        fecha_nacimiento TEXT,
        localidad TEXT,
        rango TEXT,
        fecha_inicio TEXT,
        estado TEXT,
        foto_path TEXT,
        motivo_cambio_estado TEXT,
        puntuacion REAL,
        rol TEXT,
        usuario TEXT,
        pass TEXT,
        device TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items_chequeo (
        item INTEGER,
        tipo_vehiculo TEXT,
        descripcion TEXT,
        fecha_vto TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chequeos_vehicular (
        id TEXT,
        tipo_unidad TEXT,
        unidad TEXT,
        dominio TEXT,
        marca TEXT,
        interno TEXT,
        fecha_prox_Ser TEXT,
        utilizado_por TEXT,
        inspecciono TEXT,
        tarjeta_verde TEXT,
        comprobante_patente TEXT,
        obra_base TEXT,
        comprobante_seguro TEXT,
        cedula_transporte TEXT,
        verificacion_tec TEXT,
        doc_chofer TEXT,
        item TEXT,
        estado TEXT,
        control TEXT,
        fecha TEXT,
        verifico TEXT,
        fecha_vto TEXT,
        visual_map TEXT,
        observaciones TEXT,
        reg_local TEXT
      )
    ''');
  }

  Future<int> obtenerSiguienteIdChequeo() async {
    final database = await db;
    final List<Map<String, dynamic>> resultado = await database.rawQuery(
      'SELECT MAX(CAST(id AS INTEGER)) as max_id FROM chequeos_vehicular'
    );
    int maxId = resultado.first['max_id'] ?? 0;
    return maxId + 1;
  }
}