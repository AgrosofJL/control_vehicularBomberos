// ESTO LO MODIFIQUE
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base.dart';

class CargaSincronizada {
  SupabaseClient get _supabase => Supabase.instance.client;
  final _dbHelper = DatabaseHelper();

  Future<bool> subirChequeosASupabase() async {
    try {
      debugPrint("📤 Preparando subida de auditorías vehiculares a Supabase...");

      // En entorno Web no hay transacciones locales pendientes en SQLite
      if (kIsWeb) {
        debugPrint("ℹ️ Entorno Web detectado: los chequeos se registran directamente en Supabase.");
        return true;
      }

      final dbLocal = await _dbHelper.db;
      final List<Map<String, dynamic>> registrosLocales = await dbLocal.query('chequeos_vehicular');

      if (registrosLocales.isEmpty) {
        debugPrint("ℹ️ No hay registros locales pendientes de subir.");
        return true;
      }

      List<Map<String, dynamic>> loteSubida = [];
      
      for (var fila in registrosLocales) {
        loteSubida.add({
          'id': fila['id'],
          'tipo_unidad': fila['tipo_unidad'],
          'unidad': fila['unidad'],
          'dominio': fila['dominio'],
          'marca': fila['marca'],
          'interno': fila['interno'],
          'fecha_prox_Ser': fila['fecha_prox_Ser'],
          'utilizado_por': fila['utilizado_por'],
          'inspecciono': fila['inspecciono'],
          'tarjeta_verde': fila['tarjeta_verde'],
          'comprobante_patente': fila['comprobante_patente'],
          'obra_base': fila['obra_base'],
          'comprobante_seguro': fila['comprobante_seguro'],
          'cedula_transporte': fila['cedula_transporte'],
          'verificacion_tec': fila['verificacion_tec'],
          'doc_chofer': fila['doc_chofer'],
          'item': fila['item'],
          'estado': fila['estado'],
          'control': fila['control'],
          'fecha': fila['fecha'],
          'verifico': fila['verifico'],
          'fecha_vto': fila['fecha_vto'],
          'reg_local': fila['reg_local'],
          'visual_map': fila['visual_map'], 
          'observaciones': fila['observaciones'], 
        });
      }

      await _supabase
          .from('chequeos_vehicular')
          .upsert(loteSubida, onConflict: 'reg_local,item');

      debugPrint("🚀 Sincronización exitosa: ${loteSubida.length} registros impactados.");
      return true;
    } catch (e) {
      debugPrint("❌ Error crítico subiendo datos a Supabase: $e");
      return false;
    }
  }
}