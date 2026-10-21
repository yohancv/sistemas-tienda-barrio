import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/operadora_model.dart';
import '../../data/models/recarga_model.dart';
import '../../data/repositories/recargas_repository.dart';

final recargasRepositoryProvider = Provider<RecargasRepository>((ref) {
  return RecargasRepository();
});

/// Lista completa de operadoras configuradas en la tienda (Entel, Tigo, Viva)
final operadorasListProvider = FutureProvider<List<OperadoraModel>>((ref) async {
  final repo = ref.watch(recargasRepositoryProvider);
  return repo.obtenerOperadoras(SupabaseConfig.defaultTenantId);
});

/// Filtro exclusivo de operadoras que la tienda tiene habilitadas para vender
final operadorasActivasProvider = Provider<AsyncValue<List<OperadoraModel>>>((ref) {
  final todasAsync = ref.watch(operadorasListProvider);
  return todasAsync.whenData((lista) => lista.where((op) => op.activa).toList());
});

/// Ventas de recargas registradas en el turno de caja activo
final recargasTurnoProvider = FutureProvider<List<RecargaModel>>((ref) async {
  final repo = ref.watch(recargasRepositoryProvider);
  final turnoAsync = ref.watch(cajaTurnoActivaProvider);
  final turno = turnoAsync.valueOrNull;

  return repo.obtenerVentasTurno(SupabaseConfig.defaultTenantId, turno?.id);
});

/// Métricas resumidas de recargas del turno (monto total y ganancia neta)
final resumenRecargasTurnoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(recargasRepositoryProvider);
  final turnoAsync = ref.watch(cajaTurnoActivaProvider);
  final turno = turnoAsync.valueOrNull;

  return repo.obtenerResumenRecargasTurno(SupabaseConfig.defaultTenantId, turno?.id);
});
