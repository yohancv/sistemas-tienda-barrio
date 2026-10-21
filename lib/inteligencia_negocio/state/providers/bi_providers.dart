import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/insight_model.dart';
import '../../data/repositories/bi_analytics_repository.dart';
import '../../domain/smart_business_engine.dart';

final biAnalyticsRepositoryProvider = Provider<BiAnalyticsRepository>((ref) {
  return BiAnalyticsRepository();
});

final smartBusinessEngineProvider = Provider<SmartBusinessEngine>((ref) {
  final repo = ref.watch(biAnalyticsRepositoryProvider);
  return SmartBusinessEngine(repo);
});

/// Provider reactivo de sugerencias de negocio inteligentes calculadas en SQLite
final sugerenciasInteligentesProvider =
    FutureProvider.autoDispose<List<InsightModel>>((ref) async {
  final engine = ref.watch(smartBusinessEngineProvider);
  return await engine.generarSugerencias(SupabaseConfig.defaultTenantId);
});
