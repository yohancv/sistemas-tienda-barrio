import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/repositories/venta_repository.dart';

/// Proveedor del repositorio de ventas inyectando el cliente global de Supabase
final ventaRepositoryProvider = Provider<VentaRepository>((ref) {
  return VentaRepository(SupabaseConfig.client);
});
