import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

/// Datos iniciales de demostración que se cargan UNA sola vez,
/// cuando se crea la base de datos local por primera vez.
///
/// Organizados en la jerarquía del POS: Categoría → Marca → Presentaciones.
/// En la tabla `productos`: `categoria` = Categoría, `subcategoria` = Marca.
///
/// Modelo de stock: `stock_actual` se guarda SIEMPRE en unidades sueltas.
/// Las cajas/paquetes se derivan con `unidades_por_empaque`
/// (ej. 28 botellas de Huari con caja de 12 = 2 cajas + 4 sueltas).
class SeedData {
  SeedData._();

  static const _uuid = Uuid();
  static const _t = AppConfig.defaultTenantId;

  static Future<void> cargar(Database db) async {
    final ahora = DateTime.now();
    final iso = ahora.toIso8601String();

    await db.transaction((txn) async {
      // -----------------------------------------------------------------------
      // 1. PROVEEDORES
      // -----------------------------------------------------------------------
      Future<String> proveedor(String empresa, String contacto, String tel, String dias) async {
        final id = _uuid.v4();
        await txn.insert('proveedores', {
          'id': id,
          'tenant_id': _t,
          'nombre_empresa': empresa,
          'nombre_contacto': contacto,
          'telefono': tel,
          'dias_visita': dias,
          'activo': 1,
          'created_at': iso,
        });
        return id;
      }

      final provCbn = await proveedor('Cervecería Boliviana Nacional - CBN', 'Carlos Preventista', '77712345', 'Martes y Viernes');
      final provEmbol = await proveedor('Embol S.A. (Coca-Cola / Vital)', 'Marcelo Pedidos', '76543210', 'Lunes y Jueves');
      final provPil = await proveedor('PIL Andina S.A. (Lácteos)', 'Dra. Patricia', '71234567', 'Miércoles');
      final provCoca = await proveedor('Distribuidora Yungas & Chapare (Coca)', 'Doña Martha', '78901234', 'Sábados');
      final provOriental = await proveedor('Distribuidora La Oriental (Abarrotes)', 'Jorge Camión', '70123456', 'Martes');
      final provTabacos = await proveedor('Tabacos y Golosinas El Alto', 'Roberto Mayorista', '73456789', 'Miércoles');

      // -----------------------------------------------------------------------
      // 2. CATEGORÍAS (Nivel 1) y MARCAS (Nivel 2)
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

      await categoria('Cervezas', '🍺', 1, ['Huari', 'Paceña', 'Corona']);
      await categoria('Gaseosas y Aguas', '🥤', 2, ['Coca-Cola', 'Pepsi', 'Mendocina', 'Vital', 'Hielo']);
      await categoria('Coca y Derivados', '🌿', 3, ['Hoja Seleccionada', 'Machucada']);
      await categoria('Lácteos y Embutidos', '🥛', 4, ['PIL', 'Queso Criollo']);
      await categoria('Golosinas y Snacks', '🍪', 5, ['Clorets', 'Alfajores']);
      await categoria('Cigarrillos', '🚬', 6, ['Camel', 'Derby']);
      await categoria('Abarrotes y Alimentos', '🍞', 7, ['Fino', 'Sofía', 'Arroz']);
      await categoria('Limpieza y Aseo', '🧼', 8, ['OMO']);

      // -----------------------------------------------------------------------
      // 3. PRODUCTOS (presentaciones)
      // -----------------------------------------------------------------------
      final idsProductos = <String, String>{};

      Future<String> producto({
        required String clave,
        required String nombre,
        required String categoria,
        required String marca,
        required double stock,
        required double stockMinimo,
        required double costo,
        required double precio,
        String tipoEmpaque = 'UNIDAD',
        double unidadesPorEmpaque = 1,
        double? precioEmpaque,
        String tipoUnidad = 'UNIDAD',
        bool ventaSuelta = false,
        String nombreSuelta = 'unidad',
        double unidadesEnEmpaqueVenta = 1,
        double precioSuelta = 0,
        String? proveedorId,
        String? codigoBarras,
        String? descripcion,
      }) async {
        final id = _uuid.v4();
        idsProductos[clave] = id;
        await txn.insert('productos', {
          'id': id,
          'tenant_id': _t,
          'codigo_barras': codigoBarras,
          'nombre': nombre,
          'descripcion': descripcion,
          'tipo_unidad': tipoUnidad,
          'stock_actual': stock,
          'stock_minimo': stockMinimo,
          'costo_mayorista': costo,
          'precio_venta': precio,
          'estado_activo': 1,
          'created_at': iso,
          'updated_at': iso,
          'tipo_empaque': tipoEmpaque,
          'unidades_por_empaque': unidadesPorEmpaque,
          'costo_por_empaque': costo * unidadesPorEmpaque,
          'precio_empaque_mayorista': precioEmpaque,
          'permite_venta_suelta': ventaSuelta ? 1 : 0,
          'nombre_unidad_suelta': nombreSuelta,
          'unidades_en_empaque_venta': unidadesEnEmpaqueVenta,
          'precio_venta_suelta': precioSuelta,
          'proveedor_id': proveedorId,
          'categoria': categoria,
          'subcategoria': marca,
        });

        // Kardex: carga de inventario inicial
        if (stock > 0) {
          await txn.insert('movimientos_inventario', {
            'id': _uuid.v4(),
            'tenant_id': _t,
            'producto_id': id,
            'tipo_movimiento': 'AJUSTE_POSITIVO',
            'cantidad': stock,
            'costo_unitario': costo,
            'costo_total': costo * stock,
            'motivo': 'Carga de inventario inicial',
            'stock_anterior': 0.0,
            'stock_posterior': stock,
            'created_at': iso,
          });
        }
        return id;
      }

      // ---- Cervezas ----
      await producto(clave: 'huari710', nombre: 'Huari Tradicional 710ml', categoria: 'Cervezas', marca: 'Huari',
          stock: 28, stockMinimo: 12, costo: 11, precio: 15, tipoEmpaque: 'CAJA', unidadesPorEmpaque: 12,
          precioEmpaque: 170, proveedorId: provCbn, codigoBarras: '77710001');
      await producto(clave: 'huariLata', nombre: 'Huari Lata 354ml', categoria: 'Cervezas', marca: 'Huari',
          stock: 18, stockMinimo: 6, costo: 7, precio: 10, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 6,
          precioEmpaque: 55, proveedorId: provCbn);
      await producto(clave: 'pacena710', nombre: 'Paceña Pilsener 710ml', categoria: 'Cervezas', marca: 'Paceña',
          stock: 44, stockMinimo: 12, costo: 10.5, precio: 14, tipoEmpaque: 'CAJA', unidadesPorEmpaque: 12,
          precioEmpaque: 160, proveedorId: provCbn, codigoBarras: '77710002');
      await producto(clave: 'pacenaLata', nombre: 'Paceña Lata 354ml', categoria: 'Cervezas', marca: 'Paceña',
          stock: 5, stockMinimo: 6, costo: 6.5, precio: 9, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 6,
          precioEmpaque: 50, proveedorId: provCbn);
      await producto(clave: 'corona', nombre: 'Corona Botellín 355ml', categoria: 'Cervezas', marca: 'Corona',
          stock: 12, stockMinimo: 6, costo: 9, precio: 13, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 6,
          precioEmpaque: 72, proveedorId: provCbn);

      // ---- Gaseosas y Aguas ----
      await producto(clave: 'coca500', nombre: 'Coca-Cola 500ml Personal', categoria: 'Gaseosas y Aguas', marca: 'Coca-Cola',
          stock: 30, stockMinimo: 12, costo: 3.5, precio: 5, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 12,
          precioEmpaque: 55, proveedorId: provEmbol);
      await producto(clave: 'coca2l', nombre: 'Coca-Cola 2 Litros Retornable', categoria: 'Gaseosas y Aguas', marca: 'Coca-Cola',
          stock: 18, stockMinimo: 6, costo: 10, precio: 13, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 6,
          precioEmpaque: 72, proveedorId: provEmbol, codigoBarras: '77710014');
      await producto(clave: 'coca3l', nombre: 'Coca-Cola 3 Litros Descartable', categoria: 'Gaseosas y Aguas', marca: 'Coca-Cola',
          stock: 3, stockMinimo: 4, costo: 14, precio: 18, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 4,
          precioEmpaque: 68, proveedorId: provEmbol);
      await producto(clave: 'pepsi2l', nombre: 'Pepsi 2 Litros', categoria: 'Gaseosas y Aguas', marca: 'Pepsi',
          stock: 12, stockMinimo: 6, costo: 9, precio: 12, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 6,
          precioEmpaque: 66, proveedorId: provEmbol);
      await producto(clave: 'pepsi500', nombre: 'Pepsi 500ml Personal', categoria: 'Gaseosas y Aguas', marca: 'Pepsi',
          stock: 24, stockMinimo: 12, costo: 3, precio: 4.5, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 12,
          precioEmpaque: 50, proveedorId: provEmbol);
      await producto(clave: 'mendoGuarana', nombre: 'Mendocina Guaraná 2 Litros', categoria: 'Gaseosas y Aguas', marca: 'Mendocina',
          stock: 6, stockMinimo: 6, costo: 7, precio: 10, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 6,
          precioEmpaque: 55, proveedorId: provEmbol);
      await producto(clave: 'mendoNaranja', nombre: 'Mendocina Naranja 2 Litros', categoria: 'Gaseosas y Aguas', marca: 'Mendocina',
          stock: 0, stockMinimo: 6, costo: 7, precio: 10, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 6,
          precioEmpaque: 55, proveedorId: provEmbol);
      await producto(clave: 'vital2l', nombre: 'Agua Vital 2 Litros sin gas', categoria: 'Gaseosas y Aguas', marca: 'Vital',
          stock: 10, stockMinimo: 6, costo: 5, precio: 7, tipoEmpaque: 'FARDO', unidadesPorEmpaque: 6,
          precioEmpaque: 38, proveedorId: provEmbol);
      await producto(clave: 'hielo', nombre: 'Bolsa de Hielo Cristal 2kg', categoria: 'Gaseosas y Aguas', marca: 'Hielo',
          stock: 12, stockMinimo: 4, costo: 5, precio: 8);

      // ---- Coca y Derivados ----
      await producto(clave: 'cocaHoja', nombre: 'Hoja de Coca Yungas (por libra)', categoria: 'Coca y Derivados', marca: 'Hoja Seleccionada',
          stock: 4.5, stockMinimo: 2, costo: 95, precio: 120, tipoUnidad: 'FRACCIONABLE', tipoEmpaque: 'LIBRA',
          proveedorId: provCoca);
      await producto(clave: 'machuMenta', nombre: 'Coca Machucada Menta (bolsita)', categoria: 'Coca y Derivados', marca: 'Machucada',
          stock: 8, stockMinimo: 3, costo: 4, precio: 5, proveedorId: provCoca);
      await producto(clave: 'machuBico', nombre: 'Coca Machucada Bico (bolsita)', categoria: 'Coca y Derivados', marca: 'Machucada',
          stock: 6, stockMinimo: 3, costo: 4, precio: 5, proveedorId: provCoca);

      // ---- Lácteos y Embutidos ----
      await producto(clave: 'lechePil', nombre: 'Leche PIL Bolsa 1 Litro', categoria: 'Lácteos y Embutidos', marca: 'PIL',
          stock: 15, stockMinimo: 10, costo: 5.5, precio: 7, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 10,
          precioEmpaque: 68, proveedorId: provPil);
      await producto(clave: 'yogurtPil', nombre: 'Yogurt PIL Frutilla 1 Litro', categoria: 'Lácteos y Embutidos', marca: 'PIL',
          stock: 6, stockMinimo: 4, costo: 9, precio: 12, proveedorId: provPil);
      await producto(clave: 'queso', nombre: 'Queso Criollo Chaqueño', categoria: 'Lácteos y Embutidos', marca: 'Queso Criollo',
          stock: 6.8, stockMinimo: 2.5, costo: 26, precio: 34, tipoUnidad: 'FRACCIONABLE', tipoEmpaque: 'KILO',
          proveedorId: provPil);

      // ---- Golosinas y Snacks ----
      await producto(clave: 'clorets', nombre: 'Chicles Clorets Menta', categoria: 'Golosinas y Snacks', marca: 'Clorets',
          stock: 15, stockMinimo: 5, costo: 1.5, precio: 2, tipoEmpaque: 'CAJA', unidadesPorEmpaque: 20,
          precioEmpaque: 36, proveedorId: provTabacos);
      await producto(clave: 'alfajor', nombre: 'Alfajor Triple Manjar', categoria: 'Golosinas y Snacks', marca: 'Alfajores',
          stock: 5, stockMinimo: 2, costo: 3.5, precio: 5, proveedorId: provTabacos);

      // ---- Cigarrillos (venta dual: cajetilla o cigarro suelto) ----
      await producto(clave: 'camel', nombre: 'Cigarrillos Camel Box 20', categoria: 'Cigarrillos', marca: 'Camel',
          stock: 6, stockMinimo: 2, costo: 16, precio: 22, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 10,
          ventaSuelta: true, nombreSuelta: 'cigarro', unidadesEnEmpaqueVenta: 20, precioSuelta: 1.5,
          proveedorId: provTabacos);
      await producto(clave: 'derby', nombre: 'Cigarrillos Derby Rojo 20', categoria: 'Cigarrillos', marca: 'Derby',
          stock: 4, stockMinimo: 2, costo: 12, precio: 16, tipoEmpaque: 'PAQUETE', unidadesPorEmpaque: 10,
          ventaSuelta: true, nombreSuelta: 'cigarro', unidadesEnEmpaqueVenta: 20, precioSuelta: 1,
          proveedorId: provTabacos);

      // ---- Abarrotes y Alimentos ----
      await producto(clave: 'aceite', nombre: 'Aceite Fino 1 Litro', categoria: 'Abarrotes y Alimentos', marca: 'Fino',
          stock: 3, stockMinimo: 12, costo: 9.5, precio: 12, tipoEmpaque: 'CAJA', unidadesPorEmpaque: 12,
          precioEmpaque: 138, proveedorId: provOriental, codigoBarras: '77710003');
      await producto(clave: 'pollo', nombre: 'Pollo Fresco Sofía', categoria: 'Abarrotes y Alimentos', marca: 'Sofía',
          stock: 14.2, stockMinimo: 5, costo: 14.5, precio: 18, tipoUnidad: 'FRACCIONABLE', tipoEmpaque: 'KILO');
      await producto(clave: 'arroz', nombre: 'Arroz Grano de Oro', categoria: 'Abarrotes y Alimentos', marca: 'Arroz',
          stock: 20, stockMinimo: 10, costo: 7, precio: 9, tipoUnidad: 'FRACCIONABLE', tipoEmpaque: 'KILO',
          proveedorId: provOriental);

      // ---- Limpieza y Aseo ----
      await producto(clave: 'omo', nombre: 'Detergente OMO 500g', categoria: 'Limpieza y Aseo', marca: 'OMO',
          stock: 8, stockMinimo: 4, costo: 9, precio: 12, proveedorId: provOriental);

      // -----------------------------------------------------------------------
      // 4. CLIENTES Y SU HISTORIAL DE FIADOS
      //    Los saldos se generan con ventas a crédito y abonos reales,
      //    así los triggers calculan el saldo y queda historial con fecha y hora.
      // -----------------------------------------------------------------------
      Future<String> cliente(String nombre, String tel, double limite, String notas) async {
        final id = _uuid.v4();
        await txn.insert('clientes', {
          'id': id,
          'tenant_id': _t,
          'nombre': nombre,
          'telefono': tel,
          'limite_credito': limite,
          'saldo_actual': 0.0,
          'notas': notas,
          'activo': 1,
          'created_at': iso,
          'updated_at': iso,
        });
        return id;
      }

      Future<void> ventaFiada(String clienteId, String clave, double cantidad, double precio, Duration hace) async {
        final ventaId = _uuid.v4();
        final fecha = ahora.subtract(hace).toIso8601String();
        final total = cantidad * precio;
        await txn.insert('ventas', {
          'id': ventaId,
          'tenant_id': _t,
          'cliente_id': clienteId,
          'total_venta': total,
          'metodo_pago': 'CREDITO_FIADO',
          'monto_recibido': 0.0,
          'cambio_entregado': 0.0,
          'fecha_venta': fecha,
        });
        await txn.insert('detalle_ventas', {
          'id': _uuid.v4(),
          'venta_id': ventaId,
          'producto_id': idsProductos[clave],
          'cantidad': cantidad,
          'precio_unitario': precio,
          'costo_unitario': 0.0,
          'subtotal': total,
        });
        await txn.insert('pagos_ventas', {
          'id': _uuid.v4(),
          'venta_id': ventaId,
          'tenant_id': _t,
          'metodo': 'FIADO',
          'monto': total,
          'created_at': fecha,
        });
      }

      Future<void> abono(String clienteId, double monto, Duration hace) async {
        await txn.insert('abonos_deuda', {
          'id': _uuid.v4(),
          'tenant_id': _t,
          'cliente_id': clienteId,
          'monto': monto,
          'metodo_pago': 'EFECTIVO',
          'fecha_abono': ahora.subtract(hace).toIso8601String(),
        });
      }

      final carmen = await cliente('Doña Carmen Ortiz', '71122334', 200, 'Vecina de la casa 14, paga los fines de mes');
      await ventaFiada(carmen, 'aceite', 2, 12, const Duration(days: 6, hours: 3));
      await ventaFiada(carmen, 'coca2l', 3, 13, const Duration(days: 3, hours: 5));
      await abono(carmen, 20, const Duration(days: 1, hours: 2)); // Saldo: 24 + 39 - 20 = 43

      final pedro = await cliente('Don Pedro Ramos', '72233445', 350, 'Mecánico de la esquina');
      await ventaFiada(pedro, 'pacena710', 6, 14, const Duration(days: 5, hours: 1));
      await ventaFiada(pedro, 'camel', 2, 22, const Duration(days: 2, hours: 4));
      await abono(pedro, 30, const Duration(hours: 20)); // Saldo: 84 + 44 - 30 = 98

      await cliente('Juan Carlos Albañil', '73344556', 150, 'Cliente puntual, saldo al día');

      // -----------------------------------------------------------------------
      // 5. TURNO DE CAJA ABIERTO (fondo fijo de Bs. 150)
      // -----------------------------------------------------------------------
      await txn.insert('cajas_turnos', {
        'id': _uuid.v4(),
        'tenant_id': _t,
        'fecha_apertura': iso,
        'monto_inicial': 150.0,
        'monto_esperado_efectivo': 150.0,
        'estado': 'ABIERTA',
        'created_at': iso,
      });
    });
  }
}
