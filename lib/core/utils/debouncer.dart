import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controla la ejecución retrasada de acciones repetitivas (como teclear en un buscador)
/// para evitar sobrecargar la CPU del dispositivo con filtrados innecesarios en cada pulsación.
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 250});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
