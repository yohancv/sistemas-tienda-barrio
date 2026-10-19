import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/venta_repository.dart';

/// Proveedor del repositorio de ventas local (SQLite)
final ventaRepositoryProvider = Provider<VentaRepository>((ref) {
  return VentaRepository();
});
