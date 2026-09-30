import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/movimiento_inventario_model.dart';
import '../../data/models/producto_model.dart';
import '../../data/repositories/movimientos_repository.dart';
import 'inventario_providers.dart';

/// Proveedor del repositorio de movimientos inyectando Supabase
final movimientosRepositoryProvider = Provider<MovimientosRepository>((ref) {
  return MovimientosRepository(SupabaseConfig.client);
});

/// Estado reactivo para las operaciones de desempaque y merma
class MovimientoOperacionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const MovimientoOperacionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  MovimientoOperacionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return MovimientoOperacionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Notifier que controla la ejecución atómica de desempaques y registro de mermas
class MovimientosNotifier extends StateNotifier<MovimientoOperacionState> {
  final MovimientosRepository _repository;
  final Ref _ref;

  MovimientosNotifier(this._repository, this._ref)
      : super(const MovimientoOperacionState());

  /// Ejecuta el desempaque de cajas y refresca reactivamente todo el catálogo y kardex
  Future<bool> desempaquetar({
    required Producto caja,
    required Producto unidadesDestino,
    required double cantidadCajas,
    String? motivo,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final res = await _repository.desempaquetarCaja(
        cajaId: caja.id,
        unidadesId: unidadesDestino.id,
        cantidadCajas: cantidadCajas,
        tenantId: SupabaseConfig.defaultTenantId,
        motivo: motivo,
      );

      // Invalidar proveedores de inventario y kardex
      _ref.invalidate(productosListProvider);
      _ref.invalidate(historialMovimientosProvider);
      _ref.invalidate(kardexListProvider);

      final unidadesSumadas = res['unidades_sumadas'] ?? 0;
      state = state.copyWith(
        isLoading: false,
        successMessage:
            '¡Desempaque exitoso! Se abrieron ${cantidadCajas.toInt()} caja(s) (+$unidadesSumadas unidades de ${unidadesDestino.nombre}).',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Registra una merma por rotura, vencimiento o deterioro y calcula el costo financiero
  Future<bool> registrarMerma({
    required Producto producto,
    required double cantidad,
    required String tipoMerma,
    String? motivo,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final res = await _repository.registrarMerma(
        productoId: producto.id,
        cantidad: cantidad,
        tipoMerma: tipoMerma,
        tenantId: SupabaseConfig.defaultTenantId,
        motivo: motivo,
      );

      // Refrescar inventario y kardex
      _ref.invalidate(productosListProvider);
      _ref.invalidate(historialMovimientosProvider);
      _ref.invalidate(kardexListProvider);

      final costoPerdida = (res['costo_perdida'] as num?)?.toDouble() ?? 0.0;
      state = state.copyWith(
        isLoading: false,
        successMessage:
            'Merma registrada: -${cantidad.toStringAsFixed(producto.esFraccionable ? 2 : 0)} ${producto.nombre} (Pérdida: Bs. ${costoPerdida.toStringAsFixed(2)}).',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void limpiarMensajes() {
    state = const MovimientoOperacionState();
  }
}

/// Proveedor del notifier de operaciones de movimientos
final movimientosNotifierProvider =
    StateNotifierProvider<MovimientosNotifier, MovimientoOperacionState>((ref) {
  final repo = ref.watch(movimientosRepositoryProvider);
  return MovimientosNotifier(repo, ref);
});

/// Proveedor del historial reciente de movimientos para auditoría rápida
final historialMovimientosProvider =
    FutureProvider<List<MovimientoInventario>>((ref) async {
  final repo = ref.watch(movimientosRepositoryProvider);
  return repo.obtenerHistorialMovimientos(SupabaseConfig.defaultTenantId);
});

// ============================================================================
// FILTROS Y ESTADO REACTIVO DEL KARDEX
// ============================================================================

enum PeriodoKardex { hoy, ultimos7Dias, esteMes, todos }

class KardexFiltroState {
  final PeriodoKardex periodo;
  final String filtroTipo; // 'TODOS', 'VENTA', 'MERMAS', 'DESEMPAQUES', 'AJUSTES', 'ENTRADAS'
  final String? productoId;
  final String? nombreProducto;
  final String busquedaTexto;

  const KardexFiltroState({
    this.periodo = PeriodoKardex.esteMes,
    this.filtroTipo = 'TODOS',
    this.productoId,
    this.nombreProducto,
    this.busquedaTexto = '',
  });

  DateTime? get fechaInicio {
    final now = DateTime.now();
    switch (periodo) {
      case PeriodoKardex.hoy:
        return DateTime(now.year, now.month, now.day);
      case PeriodoKardex.ultimos7Dias:
        return now.subtract(const Duration(days: 7));
      case PeriodoKardex.esteMes:
        return DateTime(now.year, now.month, 1);
      case PeriodoKardex.todos:
        return null;
    }
  }

  DateTime? get fechaFin => null;

  KardexFiltroState copyWith({
    PeriodoKardex? periodo,
    String? filtroTipo,
    String? productoId,
    String? nombreProducto,
    bool clearProducto = false,
    String? busquedaTexto,
  }) {
    return KardexFiltroState(
      periodo: periodo ?? this.periodo,
      filtroTipo: filtroTipo ?? this.filtroTipo,
      productoId: clearProducto ? null : (productoId ?? this.productoId),
      nombreProducto: clearProducto ? null : (nombreProducto ?? this.nombreProducto),
      busquedaTexto: busquedaTexto ?? this.busquedaTexto,
    );
  }
}

class KardexFiltroNotifier extends Notifier<KardexFiltroState> {
  @override
  KardexFiltroState build() => const KardexFiltroState();

  void cambiarPeriodo(PeriodoKardex periodo) {
    state = state.copyWith(periodo: periodo);
  }

  void cambiarTipo(String tipo) {
    state = state.copyWith(filtroTipo: tipo);
  }

  void seleccionarProducto(String? productoId, {String? nombreProducto}) {
    if (productoId == null) {
      state = state.copyWith(clearProducto: true);
    } else {
      state = state.copyWith(
        productoId: productoId,
        nombreProducto: nombreProducto,
      );
    }
  }

  void actualizarBusqueda(String texto) {
    state = state.copyWith(busquedaTexto: texto);
  }

  void limpiarBusquedaYProducto() {
    state = state.copyWith(
      clearProducto: true,
      busquedaTexto: '',
    );
  }

  void resetearFiltros() {
    state = const KardexFiltroState();
  }
}

final kardexFiltroProvider =
    NotifierProvider<KardexFiltroNotifier, KardexFiltroState>(
  KardexFiltroNotifier.new,
);

/// Proveedor de la lista filtrada del Kardex
final kardexListProvider =
    FutureProvider<List<MovimientoInventario>>((ref) async {
  final filtro = ref.watch(kardexFiltroProvider);
  final repo = ref.watch(movimientosRepositoryProvider);

  final movimientos = await repo.obtenerKardex(
    tenantId: SupabaseConfig.defaultTenantId,
    productoId: filtro.productoId,
    fechaInicio: filtro.fechaInicio,
    fechaFin: filtro.fechaFin,
    filtroTipo: filtro.filtroTipo,
    limite: 150,
  );

  // Filtrado local por texto de búsqueda si el usuario escribe en el buscador
  if (filtro.busquedaTexto.trim().isNotEmpty) {
    final term = filtro.busquedaTexto.toLowerCase().trim();
    return movimientos.where((m) {
      final nombre = m.nombreProducto?.toLowerCase() ?? '';
      final codigo = m.codigoBarrasProducto?.toLowerCase() ?? '';
      final motivo = m.motivo?.toLowerCase() ?? '';
      return nombre.contains(term) || codigo.contains(term) || motivo.contains(term);
    }).toList();
  }

  return movimientos;
});

/// Resumen métrico consolidado del período actual del Kardex
class ResumenKardex {
  final double totalUnidadesVendidas;
  final double totalUnidadesIngresadas;
  final double totalUnidadesMermas;
  final double totalCostoPerdidaMermas;

  const ResumenKardex({
    required this.totalUnidadesVendidas,
    required this.totalUnidadesIngresadas,
    required this.totalUnidadesMermas,
    required this.totalCostoPerdidaMermas,
  });

  factory ResumenKardex.desdeLista(List<MovimientoInventario> lista) {
    double vendidas = 0.0;
    double ingresadas = 0.0;
    double mermas = 0.0;
    double costoMermas = 0.0;

    for (final m in lista) {
      if (m.esVenta) {
        vendidas += m.cantidad;
      } else if (m.esMerma) {
        mermas += m.cantidad;
        costoMermas += m.costoTotal;
      } else if (m.esEntrada) {
        ingresadas += m.cantidad;
      }
    }

    return ResumenKardex(
      totalUnidadesVendidas: vendidas,
      totalUnidadesIngresadas: ingresadas,
      totalUnidadesMermas: mermas,
      totalCostoPerdidaMermas: costoMermas,
    );
  }
}

final resumenKardexProvider = Provider<ResumenKardex>((ref) {
  final movimientosAsync = ref.watch(kardexListProvider);
  return movimientosAsync.maybeWhen(
    data: (lista) => ResumenKardex.desdeLista(lista),
    orElse: () => const ResumenKardex(
      totalUnidadesVendidas: 0,
      totalUnidadesIngresadas: 0,
      totalUnidadesMermas: 0,
      totalCostoPerdidaMermas: 0,
    ),
  );
});
