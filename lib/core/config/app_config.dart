/// Configuración global de la aplicación (100% local / offline).
///
/// Reemplaza a la antigua `SupabaseConfig`: ya no existe un servidor en la nube,
/// toda la información vive en la base de datos SQLite del propio dispositivo.
class AppConfig {
  AppConfig._();

  /// Tenant por defecto. Se conserva la columna `tenant_id` en todas las tablas
  /// para que el día de mañana se pueda sincronizar con la nube o manejar
  /// varias sucursales sin rediseñar el esquema.
  static const String defaultTenantId = '00000000-0000-0000-0000-000000000000';

  /// Nombre del archivo de base de datos local.
  static const String nombreBaseDatos = 'tienda_barrio.db';
}
