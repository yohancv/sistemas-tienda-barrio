import 'package:sqflite_common/sqlite_api.dart';

/// Datos iniciales para una tienda nueva:
/// Inicializa la base de datos 100% limpia (0 productos, 0 clientes, 0 ventas, 0 categorías)
/// para que el cliente cree su propio catálogo y categorías desde cero.
class SeedData {
  SeedData._();

  static Future<void> cargar(Database db) async {
    // Base de datos limpia sin categorías ni productos por defecto.
  }
}
