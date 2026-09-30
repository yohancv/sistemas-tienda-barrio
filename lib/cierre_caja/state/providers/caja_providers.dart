import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/caja_turno_model.dart';
import '../../data/models/movimiento_caja_model.dart';
import '../../data/models/resumen_caja_model.dart';
import '../../data/repositories/caja_repository.dart';

/// Denominaciones oficiales de billetes y monedas en Bolivia
enum Denominacion {
  b200(valor: 200.0, etiqueta: 'Billetes de 200 Bs', esBillete: true),
  b100(valor: 100.0, etiqueta: 'Billetes de 100 Bs', esBillete: true),
  b50(valor: 50.0, etiqueta: 'Billetes de 50 Bs', esBillete: true),
  b20(valor: 20.0, etiqueta: 'Billetes de 20 Bs', esBillete: true),
  b10(valor: 10.0, etiqueta: 'Billetes de 10 Bs', esBillete: true),
  m5(valor: 5.0, etiqueta: 'Monedas de 5 Bs', esBillete: false),
  m2(valor: 2.0, etiqueta: 'Monedas de 2 Bs', esBillete: false),
  m1(valor: 1.0, etiqueta: 'Monedas de 1 Bs', esBillete: false),
  m050(valor: 0.50, etiqueta: 'Monedas de 50 Ctvs', esBillete: false);

  final double valor;
  final String etiqueta;
  final bool esBillete;

  const Denominacion({
    required this.valor,
    required this.etiqueta,
    required this.esBillete,
  });
}

/// Estado con las cantidades contadas por denominación (Conteo Ciego)
class ConteoCajaState {
  final Map<Denominacion, int> cantidades;

  const ConteoCajaState({required this.cantidades});

  factory ConteoCajaState.inicial() {
    return ConteoCajaState(
      cantidades: {for (var d in Denominacion.values) d: 0},
    );
  }

  /// Gran total declarado calculado automáticamente
  double get granTotal {
    double total = 0.0;
    cantidades.forEach((denom, cantidad) {
      total += denom.valor * cantidad;
    });
    return (total * 100).round() / 100.0;
  }

  /// Desglose en formato serializable para la BD
  Map<String, int> toMapSerializable() {
    return cantidades.map((key, value) => MapEntry(key.valor.toStringAsFixed(2), value));
  }

  ConteoCajaState copyWithCantidad(Denominacion denom, int cantidad) {
    final nuevoMap = Map<Denominacion, int>.from(cantidades);
    nuevoMap[denom] = cantidad < 0 ? 0 : cantidad;
    return ConteoCajaState(cantidades: nuevoMap);
  }
}

class ConteoCajaNotifier extends Notifier<ConteoCajaState> {
  @override
  ConteoCajaState build() => ConteoCajaState.inicial();

  void actualizarCantidad(Denominacion denom, int cantidad) {
    state = state.copyWithCantidad(denom, cantidad);
  }

  void incrementar(Denominacion denom) {
    final actual = state.cantidades[denom] ?? 0;
    state = state.copyWithCantidad(denom, actual + 1);
  }

  void decrementar(Denominacion denom) {
    final actual = state.cantidades[denom] ?? 0;
    if (actual > 0) {
      state = state.copyWithCantidad(denom, actual - 1);
    }
  }

  void reiniciar() {
    state = ConteoCajaState.inicial();
  }
}

/// Proveedor del repositorio de caja
final cajaRepositoryProvider = Provider<CajaRepository>((ref) {
  return CajaRepository(SupabaseConfig.client);
});

/// Notifier para el turno de caja actualmente activo
class CajaTurnoActivaNotifier extends AsyncNotifier<CajaTurnoModel?> {
  @override
  Future<CajaTurnoModel?> build() async {
    final repo = ref.read(cajaRepositoryProvider);
    return await repo.obtenerTurnoActivo(SupabaseConfig.defaultTenantId);
  }

  /// Refresca el turno activo
  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(cajaRepositoryProvider);
      return await repo.obtenerTurnoActivo(SupabaseConfig.defaultTenantId);
    });
  }

  /// Abre un nuevo turno de caja con fondo inicial
  Future<CajaTurnoModel> abrirTurno(double montoInicial) async {
    final repo = ref.read(cajaRepositoryProvider);
    final nuevoTurno = await repo.abrirTurno(
      tenantId: SupabaseConfig.defaultTenantId,
      montoInicial: montoInicial,
    );
    // Al actualizar el estado, los providers dependientes (resumen y movimientos)
    // se recalculan de forma reactiva y automática sin provocar CircularDependencyError.
    state = AsyncValue.data(nuevoTurno);
    return nuevoTurno;
  }

  /// Cierra el turno activo
  Future<CajaTurnoModel> cerrarTurno({
    required double montoContado,
    required ResumenCajaModel resumen,
    Map<String, int>? desglose,
    String? observaciones,
  }) async {
    final turnoActual = state.value;
    if (turnoActual == null) throw Exception('No hay turno abierto');

    final repo = ref.read(cajaRepositoryProvider);
    final turnoCerrado = await repo.cerrarTurno(
      turnoId: turnoActual.id,
      montoContado: montoContado,
      resumen: resumen,
      desglose: desglose,
      observaciones: observaciones,
    );

    // Al limpiar el estado a null, los providers dependientes se actualizan reactivamente
    state = const AsyncValue.data(null);
    return turnoCerrado;
  }
}

final cajaTurnoActivaProvider =
    AsyncNotifierProvider<CajaTurnoActivaNotifier, CajaTurnoModel?>(
  CajaTurnoActivaNotifier.new,
);

/// Proveedor booleano para validar rápidamente si la caja está abierta
final hayCajaAbiertaProvider = Provider<bool>((ref) {
  final turnoAsync = ref.watch(cajaTurnoActivaProvider);
  return turnoAsync.maybeWhen(
    data: (turno) => turno != null && turno.estaAbierta,
    orElse: () => false,
  );
});

/// Proveedor del resumen financiero en vivo del turno actual
final resumenCajaTurnoProvider = FutureProvider<ResumenCajaModel?>((ref) async {
  final turno = ref.watch(cajaTurnoActivaProvider).value;
  if (turno == null) return null;

  final repo = ref.read(cajaRepositoryProvider);
  return await repo.obtenerResumenTurno(turno.id, SupabaseConfig.defaultTenantId);
});

/// Proveedor de movimientos manuales de caja del turno actual
final movimientosCajaTurnoProvider =
    FutureProvider<List<MovimientoCajaModel>>((ref) async {
  final turno = ref.watch(cajaTurnoActivaProvider).value;
  if (turno == null) return [];

  final repo = ref.read(cajaRepositoryProvider);
  return await repo.obtenerMovimientosTurno(turno.id);
});

/// Proveedor del conteo ciego de billetes y monedas
final conteoCajaProvider =
    NotifierProvider<ConteoCajaNotifier, ConteoCajaState>(
  ConteoCajaNotifier.new,
);

/// Aliases para mantener compatibilidad hacia atrás si algún widget viejo los usa
typedef CajaState = ConteoCajaState;
typedef CajaNotifier = ConteoCajaNotifier;
final cajaProvider = conteoCajaProvider;
