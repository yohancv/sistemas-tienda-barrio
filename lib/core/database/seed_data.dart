import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

/// Datos iniciales base para una tienda nueva:
/// Carga únicamente el catálogo de Categorías y Marcas estándar de tienda de barrio
/// para que el cliente comience con su inventario desde cero (0 productos, 0 clientes, 0 ventas).
class SeedData {
  SeedData._();

  static const _uuid = Uuid();
  static const _t = AppConfig.defaultTenantId;

  static Future<void> cargar(Database db) async {
    final ahora = DateTime.now();
    final iso = ahora.toIso8601String();

    await db.transaction((txn) async {
      // -----------------------------------------------------------------------
      // CATEGORÍAS (Nivel 1) y MARCAS / SUBCATEGORÍAS (Nivel 2)
      // -----------------------------------------------------------------------
      Future<void> categoria(String nombre, String icono, int orden, List<String> marcas) async {
        final id = _uuid.v4();
        await txn.insert('categorias', {
          'id': id,
          'tenant_id': _t,
          'nombre': nombre,
          'icono': icono,
          'orden': orden,
          'created_at': iso,
          'updated_at': iso,
        });
        for (var i = 0; i < marcas.length; i++) {
          await txn.insert('categorias', {
            'id': _uuid.v4(),
            'tenant_id': _t,
            'nombre': marcas[i],
            'parent_id': id,
            'orden': i + 1,
            'created_at': iso,
            'updated_at': iso,
          });
        }
      }

      await categoria('Abarrotes y Alimentos', '🍞', 1, ['Fino', 'Sofía', 'Arroz', 'Fideos', 'Azúcar']);
      await categoria('Lácteos y Embutidos', '🥛', 2, ['PIL', 'Queso Criollo', 'Yogurt']);
      await categoria('Gaseosas y Aguas', '🥤', 3, ['Coca-Cola', 'Pepsi', 'Mendocina', 'Vital', 'Hielo']);
      await categoria('Cervezas', '🍺', 4, ['Huari', 'Paceña', 'Corona', 'Taquiña']);
      await categoria('Golosinas y Snacks', '🍪', 5, ['Chocolates', 'Galletas', 'Chicles', 'Alfajores']);
      await categoria('Limpieza y Aseo', '🧼', 6, ['Detergente', 'Jabón', 'Lavandina', 'Papel Higiénico']);
      await categoria('Cigarrillos', '🚬', 7, ['Camel', 'Derby', 'Lucky Strike']);
      await categoria('Coca y Derivados', '🌿', 8, ['Hoja Seleccionada', 'Machucada', 'Bico']);
    });
  }
}
