import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier que gestiona el efectivo recibido en la pantalla de cobro
class EfectivoRecibidoNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  /// Suma la denominación del billete pulsado
  void sumar(double monto) {
    final nuevoTotal = state + monto;
    state = (nuevoTotal * 100).round() / 100.0;
  }

  /// Fija directamente el monto exacto de la cuenta
  void fijarMontoExacto(double total) {
    state = total;
  }

  /// Reinicia el dinero recibido a cero en caso de equivocación
  void corregir() {
    state = 0.0;
  }
}

final efectivoRecibidoProvider =
    NotifierProvider<EfectivoRecibidoNotifier, double>(
  EfectivoRecibidoNotifier.new,
);
