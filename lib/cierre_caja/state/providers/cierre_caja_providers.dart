import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/repositories/cierre_caja_repository.dart';

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

/// Estado con las cantidades contadas por denominación
class CajaState {
  final Map<Denominacion, int> cantidades;

  const CajaState({required this.cantidades});

  factory CajaState.inicial() {
    return CajaState(
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

  CajaState copyWithCantidad(Denominacion denom, int cantidad) {
    final nuevoMap = Map<Denominacion, int>.from(cantidades);
    nuevoMap[denom] = cantidad < 0 ? 0 : cantidad;
    return CajaState(cantidades: nuevoMap);
  }
}

class CajaNotifier extends Notifier<CajaState> {
  @override
  CajaState build() => CajaState.inicial();

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
    state = CajaState.inicial();
  }
}

final cajaProvider = NotifierProvider<CajaNotifier, CajaState>(
  CajaNotifier.new,
);

final cierreCajaRepositoryProvider = Provider<CierreCajaRepository>((ref) {
  return CierreCajaRepository(SupabaseConfig.client);
});
