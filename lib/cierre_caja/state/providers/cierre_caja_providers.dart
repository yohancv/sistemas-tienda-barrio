export 'caja_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/repositories/cierre_caja_repository.dart';

final cierreCajaRepositoryProvider = Provider<CierreCajaRepository>((ref) {
  return CierreCajaRepository(SupabaseConfig.client);
});
