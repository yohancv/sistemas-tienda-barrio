import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import 'db_factory.dart';
import 'seed_data.dart';

/// Base de datos local SQLite (100% offline, costo $0).
///
/// Traduce a SQLite el esquema que antes vivía en Supabase
/// (`supabase/migrations/01..16`), conservando las reglas de negocio:
/// - Inmutabilidad financiera: ventas, pagos, abonos y kardex no admiten UPDATE/DELETE (triggers).
/// - Saldo de fiados sincronizado automáticamente por triggers (venta a crédito suma, abono resta).
/// - Soft delete en productos, clientes y proveedores (`estado_activo` / `activo`).
/// - Columna `tenant_id` en todas las tablas para una futura sincronización con la nube.
class AppDatabase {
  AppDatabase._();

  /// Instancia única compartida por todos los repositorios.
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 1;
  static const Uuid _uuid = Uuid();

  Database? _db;
  Future<Database>? _abriendo;

  static bool _columnasAseguradas = false;

  /// Conexión abierta (se abre y siembra datos la primera vez).
  Future<Database> get database async {
    if (_db != null) {
      await _asegurarColumnas(_db!);
      return _db!;
    }
    _abriendo ??= _abrir();
    _db = await _abriendo;
    await _asegurarColumnas(_db!);
    return _db!;
  }

  /// Verifica e inyecta dinámicamente columnas nuevas en compras si no existen
  static Future<void> _asegurarColumnas(Database db) async {
    if (_columnasAseguradas) return;
    try {
      final info = await db.rawQuery('PRAGMA table_info(compras)');
      final columnas = info.map((c) => c['name'] as String).toSet();
      if (!columnas.contains('estado')) {
        await db.execute("ALTER TABLE compras ADD COLUMN estado TEXT NOT NULL DEFAULT 'COMPLETADA'");
      }
      if (!columnas.contains('fecha_entrega')) {
        await db.execute('ALTER TABLE compras ADD COLUMN fecha_entrega TEXT');
      }
      if (!columnas.contains('created_at')) {
        await db.execute('ALTER TABLE compras ADD COLUMN created_at TEXT');
      }
      _columnasAseguradas = true;
    } catch (_) {}
  }

  /// Genera un identificador único (UUID v4) para nuevas filas.
  static String nuevoId() => _uuid.v4();

  /// Marca de tiempo local en formato ISO-8601 (ordenable como texto).
  static String ahora() => DateTime.now().toIso8601String();

  /// Convierte un mapa de modelo a una fila válida para SQLite:
  /// bool → 0/1, DateTime → ISO-8601, Map/List → JSON.
  static Map<String, Object?> aFila(Map<String, dynamic> map) {
    final fila = <String, Object?>{};
    map.forEach((clave, valor) {
      if (valor is bool) {
        fila[clave] = valor ? 1 : 0;
      } else if (valor is DateTime) {
        fila[clave] = valor.toIso8601String();
      } else if (valor is Map || valor is List) {
        fila[clave] = jsonEncode(valor);
      } else {
        fila[clave] = valor;
      }
    });
    return fila;
  }

  /// Copia mutable de una fila (las filas de sqflite son de solo lectura).
  static Map<String, dynamic> aMapa(Map<String, Object?> fila) =>
      Map<String, dynamic>.from(fila);

  Future<Database> _abrir() async {
    final factory = obtenerDatabaseFactory();
    final ruta = await obtenerRutaBaseDatos(AppConfig.nombreBaseDatos);

    return factory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _crearEsquema(db);
          await SeedData.cargar(db);
        },
        onOpen: (db) async {
          // Migración segura para compras: estado y fecha_entrega
          try {
            final info = await db.rawQuery('PRAGMA table_info(compras)');
            final columnas = info.map((c) => c['name'] as String).toSet();
            if (!columnas.contains('estado')) {
              await db.execute("ALTER TABLE compras ADD COLUMN estado TEXT NOT NULL DEFAULT 'COMPLETADA'");
            }
            if (!columnas.contains('fecha_entrega')) {
              await db.execute('ALTER TABLE compras ADD COLUMN fecha_entrega TEXT');
            }
          } catch (_) {}
        },
      ),
    );
  }

  /// Cierra la conexión (útil para respaldos o pruebas).
  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
    _abriendo = null;
  }

  // ---------------------------------------------------------------------------
  // ESQUEMA
  // ---------------------------------------------------------------------------

  static Future<void> _crearEsquema(Database db) async {
    final batch = db.batch();

    // --- Proveedores ---
    batch.execute('''
      CREATE TABLE proveedores (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        nombre_empresa TEXT NOT NULL,
        nombre_contacto TEXT,
        telefono TEXT,
        nit_ci TEXT,
        dias_visita TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // --- Categorías (Nivel 1) y Marcas / Subcategorías (Nivel 2) ---
    batch.execute('''
      CREATE TABLE categorias (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        nombre TEXT NOT NULL,
        parent_id TEXT REFERENCES categorias(id) ON DELETE CASCADE,
        icono TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // --- Productos (empaques mayoristas, venta dual, granel) ---
    batch.execute('''
      CREATE TABLE productos (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        codigo_barras TEXT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        tipo_unidad TEXT NOT NULL DEFAULT 'UNIDAD',
        stock_actual REAL NOT NULL DEFAULT 0,
        stock_minimo REAL NOT NULL DEFAULT 0,
        costo_mayorista REAL NOT NULL DEFAULT 0,
        precio_venta REAL NOT NULL DEFAULT 0,
        estado_activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        tipo_empaque TEXT NOT NULL DEFAULT 'UNIDAD',
        unidades_por_empaque REAL NOT NULL DEFAULT 1,
        costo_por_empaque REAL NOT NULL DEFAULT 0,
        precio_empaque_mayorista REAL,
        permite_venta_suelta INTEGER NOT NULL DEFAULT 0,
        nombre_unidad_suelta TEXT DEFAULT 'unidad',
        unidades_en_empaque_venta REAL NOT NULL DEFAULT 1,
        precio_venta_suelta REAL NOT NULL DEFAULT 0,
        producto_hijo_id TEXT REFERENCES productos(id) ON DELETE SET NULL,
        proveedor_id TEXT REFERENCES proveedores(id) ON DELETE SET NULL,
        categoria TEXT,
        subcategoria TEXT,
        imagen_path TEXT
      )
    ''');

    // --- Clientes (fiados) ---
    batch.execute('''
      CREATE TABLE clientes (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        nombre TEXT NOT NULL,
        telefono TEXT,
        limite_credito REAL NOT NULL DEFAULT 100,
        saldo_actual REAL NOT NULL DEFAULT 0,
        notas TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // --- Turnos de caja ---
    batch.execute('''
      CREATE TABLE cajas_turnos (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        usuario_id TEXT,
        fecha_apertura TEXT NOT NULL,
        monto_inicial REAL NOT NULL DEFAULT 0,
        fecha_cierre TEXT,
        total_ventas_efectivo REAL NOT NULL DEFAULT 0,
        total_ventas_qr REAL NOT NULL DEFAULT 0,
        total_fiados_otorgados REAL NOT NULL DEFAULT 0,
        total_fiados_cobrados_efectivo REAL NOT NULL DEFAULT 0,
        total_fiados_cobrados_qr REAL NOT NULL DEFAULT 0,
        total_salidas_manuales REAL NOT NULL DEFAULT 0,
        total_entradas_manuales REAL NOT NULL DEFAULT 0,
        total_retiros_qr REAL NOT NULL DEFAULT 0,
        total_salidas_tienda REAL NOT NULL DEFAULT 0,
        total_salidas_personal REAL NOT NULL DEFAULT 0,
        saldo_neto_qr REAL NOT NULL DEFAULT 0,
        monto_esperado_efectivo REAL NOT NULL DEFAULT 0,
        monto_real_contado REAL,
        diferencia REAL,
        desglose_efectivo TEXT,
        observaciones_cierre TEXT,
        estado TEXT NOT NULL DEFAULT 'ABIERTA' CHECK (estado IN ('ABIERTA', 'CERRADA')),
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // --- Movimientos manuales de caja (gastos, retiros, entradas) ---
    batch.execute('''
      CREATE TABLE movimientos_caja (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        turno_id TEXT NOT NULL REFERENCES cajas_turnos(id) ON DELETE CASCADE,
        tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA')),
        monto REAL NOT NULL CHECK (monto > 0),
        motivo TEXT NOT NULL,
        origen_dinero TEXT NOT NULL DEFAULT 'EFECTIVO_CAJA',
        categoria TEXT NOT NULL DEFAULT 'GASTO_TIENDA',
        created_at TEXT NOT NULL
      )
    ''');

    // --- Ventas (inmutables) ---
    batch.execute('''
      CREATE TABLE ventas (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        cliente_id TEXT REFERENCES clientes(id),
        caja_turno_id TEXT REFERENCES cajas_turnos(id),
        total_venta REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        monto_recibido REAL NOT NULL DEFAULT 0,
        cambio_entregado REAL NOT NULL DEFAULT 0,
        fecha_venta TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE detalle_ventas (
        id TEXT PRIMARY KEY,
        venta_id TEXT NOT NULL REFERENCES ventas(id),
        producto_id TEXT NOT NULL REFERENCES productos(id),
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        costo_unitario REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE pagos_ventas (
        id TEXT PRIMARY KEY,
        venta_id TEXT NOT NULL REFERENCES ventas(id),
        tenant_id TEXT NOT NULL,
        metodo TEXT NOT NULL,
        monto REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // --- Abonos a deuda (inmutables) ---
    batch.execute('''
      CREATE TABLE abonos_deuda (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL REFERENCES clientes(id),
        monto REAL NOT NULL CHECK (monto > 0),
        metodo_pago TEXT NOT NULL DEFAULT 'EFECTIVO',
        notas TEXT,
        fecha_abono TEXT NOT NULL,
        caja_turno_id TEXT REFERENCES cajas_turnos(id)
      )
    ''');

    // --- Kardex / movimientos de inventario (inmutables) ---
    batch.execute('''
      CREATE TABLE movimientos_inventario (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        producto_id TEXT NOT NULL REFERENCES productos(id),
        tipo_movimiento TEXT NOT NULL,
        cantidad REAL NOT NULL,
        costo_unitario REAL NOT NULL DEFAULT 0,
        costo_total REAL NOT NULL DEFAULT 0,
        motivo TEXT,
        referencia_id TEXT,
        stock_anterior REAL,
        stock_posterior REAL,
        usuario_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // --- Compras a proveedores ---
    batch.execute('''
      CREATE TABLE compras (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        proveedor_id TEXT REFERENCES proveedores(id) ON DELETE SET NULL,
        numero_comprobante TEXT,
        total_compra REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        monto_pagado_caja REAL NOT NULL DEFAULT 0,
        monto_pagado_externo REAL NOT NULL DEFAULT 0,
        caja_turno_id TEXT REFERENCES cajas_turnos(id),
        observaciones TEXT,
        estado TEXT NOT NULL DEFAULT 'COMPLETADA',
        fecha_entrega TEXT,
        created_at TEXT,
        fecha_compra TEXT NOT NULL,
        usuario_id TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE detalle_compras (
        id TEXT PRIMARY KEY,
        compra_id TEXT NOT NULL REFERENCES compras(id) ON DELETE CASCADE,
        producto_id TEXT NOT NULL REFERENCES productos(id),
        cantidad REAL NOT NULL CHECK (cantidad > 0),
        costo_unitario REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        nuevo_precio_venta REAL
      )
    ''');

    // --- Cierres de caja legacy (compatibilidad) ---
    batch.execute('''
      CREATE TABLE cierres_caja (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        fondo_fijo REAL NOT NULL DEFAULT 0,
        monto_declarado REAL,
        monto_esperado REAL,
        descuadre REAL,
        estado TEXT NOT NULL,
        notas TEXT,
        fecha_cierre TEXT NOT NULL
      )
    ''');

    // -------------------------------------------------------------------------
    // ÍNDICES
    // -------------------------------------------------------------------------
    const indices = [
      'CREATE INDEX idx_productos_tenant_activo ON productos(tenant_id, estado_activo)',
      'CREATE INDEX idx_productos_cat_subcat ON productos(tenant_id, categoria, subcategoria)',
      'CREATE INDEX idx_productos_hijo ON productos(producto_hijo_id)',
      "CREATE UNIQUE INDEX idx_productos_codigo_barras_unico ON productos(tenant_id, codigo_barras) "
          "WHERE estado_activo = 1 AND codigo_barras IS NOT NULL AND codigo_barras <> ''",
      'CREATE INDEX idx_categorias_parent ON categorias(tenant_id, parent_id)',
      'CREATE INDEX idx_clientes_tenant_saldo ON clientes(tenant_id, saldo_actual DESC)',
      'CREATE INDEX idx_abonos_cliente_fecha ON abonos_deuda(cliente_id, fecha_abono DESC)',
      'CREATE INDEX idx_ventas_tenant_fecha ON ventas(tenant_id, fecha_venta DESC)',
      'CREATE INDEX idx_ventas_cliente ON ventas(cliente_id)',
      'CREATE INDEX idx_ventas_turno ON ventas(caja_turno_id)',
      'CREATE INDEX idx_detalle_ventas_venta ON detalle_ventas(venta_id)',
      'CREATE INDEX idx_pagos_ventas_venta ON pagos_ventas(venta_id)',
      'CREATE INDEX idx_movinv_tenant_fecha ON movimientos_inventario(tenant_id, created_at DESC)',
      'CREATE INDEX idx_movinv_producto ON movimientos_inventario(producto_id)',
      'CREATE INDEX idx_movcaja_turno ON movimientos_caja(turno_id, created_at DESC)',
      'CREATE INDEX idx_turnos_tenant_estado ON cajas_turnos(tenant_id, estado)',
      'CREATE INDEX idx_compras_tenant_fecha ON compras(tenant_id, fecha_compra DESC)',
      'CREATE INDEX idx_detalle_compras_compra ON detalle_compras(compra_id)',
    ];
    for (final sql in indices) {
      batch.execute(sql);
    }

    // -------------------------------------------------------------------------
    // TRIGGERS: INMUTABILIDAD FINANCIERA (NO UPDATE / NO DELETE)
    // -------------------------------------------------------------------------
    const tablasInmutables = {
      'ventas': 'Las ventas confirmadas son inmutables. Use una anulación documentada.',
      'detalle_ventas': 'El detalle de ventas es inmutable.',
      'pagos_ventas': 'Los pagos de ventas son inmutables.',
      'abonos_deuda': 'Los abonos de deuda son inmutables por auditoría contable.',
      'movimientos_inventario': 'Los movimientos de inventario (Kardex) son inmutables.',
    };
    tablasInmutables.forEach((tabla, mensaje) {
      batch.execute('''
        CREATE TRIGGER trg_${tabla}_no_update BEFORE UPDATE ON $tabla
        BEGIN SELECT RAISE(ABORT, '$mensaje'); END
      ''');
      batch.execute('''
        CREATE TRIGGER trg_${tabla}_no_delete BEFORE DELETE ON $tabla
        BEGIN SELECT RAISE(ABORT, '$mensaje'); END
      ''');
    });

    // -------------------------------------------------------------------------
    // TRIGGERS: SINCRONIZACIÓN AUTOMÁTICA DEL SALDO DE FIADOS
    // -------------------------------------------------------------------------
    batch.execute('''
      CREATE TRIGGER trg_saldo_cliente_por_venta AFTER INSERT ON ventas
      WHEN NEW.metodo_pago = 'CREDITO_FIADO' AND NEW.cliente_id IS NOT NULL
      BEGIN
        UPDATE clientes
        SET saldo_actual = saldo_actual + NEW.total_venta,
            updated_at = NEW.fecha_venta
        WHERE id = NEW.cliente_id;
      END
    ''');

    batch.execute('''
      CREATE TRIGGER trg_saldo_cliente_por_abono AFTER INSERT ON abonos_deuda
      BEGIN
        UPDATE clientes
        SET saldo_actual = saldo_actual - NEW.monto,
            updated_at = NEW.fecha_abono
        WHERE id = NEW.cliente_id;
      END
    ''');

    await batch.commit(noResult: true);
  }
}
