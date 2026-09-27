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

  /// Ejecuta el desempaque de cajas y refresca reactivamente todo el catálogo
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

      // Invalidar proveedores de inventario para que el stock se actualice en toda la app de inmediato
      _ref.invalidate(productosListProvider);
      _ref.invalidate(historialMovimientosProvider);

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

      // Refrescar inventario
      _ref.invalidate(productosListProvider);
      _ref.invalidate(historialMovimientosProvider);

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

/// Proveedor del historial reciente de movimientos para auditoría
final historialMovimientosProvider =
    FutureProvider<List<MovimientoInventario>>((ref) async {
  final repo = ref.watch(movimientosRepositoryProvider);
  return repo.obtenerHistorialMovimientos(SupabaseConfig.defaultTenantId);
});
