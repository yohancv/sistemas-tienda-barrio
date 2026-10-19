import '../database/app_database.dart';
import 'app_config.dart';

/// Capa de retrocompatibilidad tras la migración a SQLite local.
///
/// Todas las operaciones ahora se ejecutan en SQLite a través de [AppDatabase].
class SupabaseConfig {
  SupabaseConfig._();

  static const String defaultTenantId = AppConfig.defaultTenantId;

  /// Inicializa la base de datos local SQLite (100% offline, costo $0).
  static Future<void> initialize() async {
    await AppDatabase.instance.database;
  }
}
