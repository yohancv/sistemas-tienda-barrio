import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/reporte_financiero_model.dart';
import '../../data/repositories/reportes_repository.dart';

/// Proveedor del repositorio de reportes
final reportesRepositoryProvider = Provider<ReportesRepository>((ref) {
  return ReportesRepository();
});

/// Período seleccionado para el dashboard (Hoy, Esta Semana, Este Mes)
final filtroPeriodoDashboardProvider = StateProvider<PeriodoFiltroReporte>((ref) {
  return PeriodoFiltroReporte.hoy;
});

/// Datos consolidados reactivos del Dashboard según el período activo
final reporteDashboardProvider = FutureProvider.autoDispose<DashboardReporteCompleto>((ref) async {
  final repo = ref.watch(reportesRepositoryProvider);
  final periodo = ref.watch(filtroPeriodoDashboardProvider);
  return await repo.obtenerReporteCompleto(periodo);
});
