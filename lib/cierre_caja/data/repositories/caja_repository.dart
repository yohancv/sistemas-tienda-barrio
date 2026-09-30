import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/caja_turno_model.dart';
import '../models/movimiento_caja_model.dart';
import '../models/resumen_caja_model.dart';

class CajaRepository {
  final SupabaseClient _client;

  CajaRepository(this._client);

  /// Obtiene el turno de caja abierto actualmente para el tenant
  Future<CajaTurnoModel?> obtenerTurnoActivo(String tenantId) async {
    try {
      final response = await _client
          .from('cajas_turnos')
          .select()
          .eq('tenant_id', tenantId)
          .eq('estado', 'ABIERTA')
          .order('fecha_apertura', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return CajaTurnoModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Inicia un nuevo turno de caja con el fondo inicial en Bs.
  Future<CajaTurnoModel> abrirTurno({
    required String tenantId,
    required double montoInicial,
    String? usuarioId,
  }) async {
    try {
      // Verificar si ya hay una caja abierta para evitar duplicar turnos
      final turnoExistente = await obtenerTurnoActivo(tenantId);
      if (turnoExistente != null) {
        throw Exception('Ya existe un turno de caja abierto iniciado el ${turnoExistente.fechaApertura}');
      }

      final payload = {
        'tenant_id': tenantId,
        'monto_inicial': montoInicial,
        'monto_esperado_efectivo': montoInicial,
        'estado': 'ABIERTA',
        'usuario_id': ?usuarioId,
      };

      final response = await _client
          .from('cajas_turnos')
          .insert(payload)
          .select()
          .single();

      return CajaTurnoModel.fromMap(response);
    } catch (e) {
      throw Exception('Error al abrir turno de caja: $e');
    }
  }

  /// Calcula el resumen financiero consolidado del turno
  Future<ResumenCajaModel> obtenerResumenTurno(String turnoId, String tenantId) async {
    try {
      // 1. Intentar por RPC de base de datos (óptimo y atómico)
      final rpcRes = await _client.rpc(
        'fn_resumen_turno_caja',
        params: {
          'p_turno_id': turnoId,
          'p_tenant_id': tenantId,
        },
      );

      final Map<String, dynamic> data = rpcRes is String
          ? jsonDecode(rpcRes)
          : Map<String, dynamic>.from(rpcRes as Map);

      return ResumenCajaModel.fromMap(data);
    } catch (e) {
      // 2. Fallback en caso de que la función RPC no esté creada aún
      return await _calcularResumenFallback(turnoId, tenantId);
    }
  }

  /// Cálculo directo de respaldo en caso de que la RPC no se haya ejecutado aún
  Future<ResumenCajaModel> _calcularResumenFallback(String turnoId, String tenantId) async {
    final turnoData = await _client
        .from('cajas_turnos')
        .select()
        .eq('id', turnoId)
        .single();

    final turno = CajaTurnoModel.fromMap(turnoData);

    // Movimientos de caja
    final movsData = await _client
        .from('movimientos_caja')
        .select('tipo, monto')
        .eq('turno_id', turnoId);

    double totalEntradas = 0.0;
    double totalSalidas = 0.0;
    for (final row in (movsData as List<dynamic>)) {
      final tipo = row['tipo'];
      final monto = (row['monto'] as num).toDouble();
      if (tipo == 'ENTRADA') totalEntradas += monto;
      if (tipo == 'SALIDA') totalSalidas += monto;
    }

    // Pagos ventas
    final pagosData = await _client
        .from('pagos_ventas')
        .select('metodo, monto, created_at')
        .eq('tenant_id', tenantId)
        .gte('created_at', turno.fechaApertura.toIso8601String());

    double ventasEfectivo = 0.0;
    double ventasQr = 0.0;
    for (final row in (pagosData as List<dynamic>)) {
      final metodo = row['metodo'];
      final monto = (row['monto'] as num).toDouble();
      if (metodo == 'EFECTIVO') ventasEfectivo += monto;
      if (metodo == 'QR') ventasQr += monto;
    }

    // Abonos deuda
    final abonosData = await _client
        .from('abonos_deuda')
        .select('metodo_pago, monto, fecha_abono')
        .eq('tenant_id', tenantId)
        .gte('fecha_abono', turno.fechaApertura.toIso8601String());

    double fiadosCobradosEfectivo = 0.0;
    double fiadosCobradosQr = 0.0;
    for (final row in (abonosData as List<dynamic>)) {
      final metodo = row['metodo_pago'];
      final monto = (row['monto'] as num).toDouble();
      if (metodo == 'EFECTIVO') fiadosCobradosEfectivo += monto;
      if (metodo == 'QR' || metodo == 'TRANSFERENCIA') fiadosCobradosQr += monto;
    }

    // Fiados otorgados
    final ventasFiadas = await _client
        .from('ventas')
        .select('total_venta, fecha_venta')
        .eq('tenant_id', tenantId)
        .eq('metodo_pago', 'CREDITO_FIADO')
        .gte('fecha_venta', turno.fechaApertura.toIso8601String());

    double fiadosOtorgados = 0.0;
    for (final row in (ventasFiadas as List<dynamic>)) {
      fiadosOtorgados += (row['total_venta'] as num).toDouble();
    }

    final esperado = turno.montoInicial +
        ventasEfectivo +
        fiadosCobradosEfectivo +
        totalEntradas -
        totalSalidas;

    return ResumenCajaModel(
      turnoId: turnoId,
      estado: turno.estado,
      fechaApertura: turno.fechaApertura,
      montoInicial: turno.montoInicial,
      totalVentasEfectivo: ventasEfectivo,
      totalVentasQr: ventasQr,
      totalFiadosOtorgados: fiadosOtorgados,
      totalFiadosCobradosEfectivo: fiadosCobradosEfectivo,
      totalFiadosCobradosQr: fiadosCobradosQr,
      totalEntradasManuales: totalEntradas,
      totalSalidasManuales: totalSalidas,
      montoEsperadoEfectivo: (esperado * 100).round() / 100.0,
    );
  }

  /// Registra una entrada o salida manual de efectivo en la caja
  Future<MovimientoCajaModel> registrarMovimientoManual({
    required String tenantId,
    required String turnoId,
    required String tipo,
    required double monto,
    required String motivo,
  }) async {
    try {
      final payload = {
        'tenant_id': tenantId,
        'turno_id': turnoId,
        'tipo': tipo,
        'monto': monto,
        'motivo': motivo,
      };

      final response = await _client
          .from('movimientos_caja')
          .insert(payload)
          .select()
          .single();

      return MovimientoCajaModel.fromMap(response);
    } catch (e) {
      throw Exception('Error al registrar movimiento de caja: $e');
    }
  }

  /// Lista los movimientos manuales registrados durante el turno
  Future<List<MovimientoCajaModel>> obtenerMovimientosTurno(String turnoId) async {
    try {
      final response = await _client
          .from('movimientos_caja')
          .select()
          .eq('turno_id', turnoId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((m) => MovimientoCajaModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cierra definitivamente el turno de caja congelando todos los totales
  Future<CajaTurnoModel> cerrarTurno({
    required String turnoId,
    required double montoContado,
    required ResumenCajaModel resumen,
    Map<String, int>? desglose,
    String? observaciones,
  }) async {
    try {
      final double diferencia =
          ((montoContado - resumen.montoEsperadoEfectivo) * 100).round() / 100.0;

      final payload = {
        'fecha_cierre': DateTime.now().toIso8601String(),
        'total_ventas_efectivo': resumen.totalVentasEfectivo,
        'total_ventas_qr': resumen.totalVentasQr,
        'total_fiados_otorgados': resumen.totalFiadosOtorgados,
        'total_fiados_cobrados_efectivo': resumen.totalFiadosCobradosEfectivo,
        'total_fiados_cobrados_qr': resumen.totalFiadosCobradosQr,
        'total_entradas_manuales': resumen.totalEntradasManuales,
        'total_salidas_manuales': resumen.totalSalidasManuales,
        'monto_esperado_efectivo': resumen.montoEsperadoEfectivo,
        'monto_real_contado': montoContado,
        'diferencia': diferencia,
        'desglose_efectivo': ?desglose,
        if (observaciones != null && observaciones.trim().isNotEmpty)
          'observaciones_cierre': observaciones.trim(),
        'estado': 'CERRADA',
      };

      final response = await _client
          .from('cajas_turnos')
          .update(payload)
          .eq('id', turnoId)
          .select()
          .single();

      return CajaTurnoModel.fromMap(response);
    } catch (e) {
      throw Exception('Error al cerrar turno de caja: $e');
    }
  }

  /// Obtiene los turnos históricos cerrados
  Future<List<CajaTurnoModel>> obtenerHistorialTurnos(
    String tenantId, {
    int limite = 20,
  }) async {
    try {
      final response = await _client
          .from('cajas_turnos')
          .select()
          .eq('tenant_id', tenantId)
          .order('fecha_apertura', ascending: false)
          .limit(limite);

      return (response as List<dynamic>)
          .map((m) => CajaTurnoModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
