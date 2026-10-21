import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

/// Servicio integral para Exportación, Importación y Respaldo Completo de LicorPOS.
/// 
/// Garantiza:
/// 1. Respaldo 100% integral de toda la base de datos (productos, categorías, clientes, deudas, ventas, caja, recargas).
/// 2. Integridad transaccional: Si ocurre un error durante la restauración, se ejecuta ROLLBACK automático.
/// 3. Compatibilidad con compartir nativo (WhatsApp, Google Drive, Correo, Bluetooth).
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const int versionFormato = 1;

  /// Exporta el 100% de la base de datos y configuraciones a un archivo JSON seguro y lo comparte.
  Future<Map<String, dynamic>> exportarYCompartirRespaldo({bool esModoOscuro = false}) async {
    final db = await AppDatabase.instance.database;

    // 1. Obtener todas las tablas existentes en la base de datos
    final tablasInfo = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    final tablas = tablasInfo.map((t) => t['name'] as String).toList();

    // 2. Extraer todos los registros tabla por tabla
    final Map<String, dynamic> datosTablas = {};
    int totalRegistros = 0;
    int totalProductos = 0;
    int totalClientes = 0;
    int totalVentas = 0;
    int totalCategorias = 0;
    int totalProveedores = 0;
    double totalDeudaCalle = 0.0;

    for (final tabla in tablas) {
      final filas = await db.query(tabla);
      datosTablas[tabla] = filas;
      totalRegistros += filas.length;

      if (tabla == 'productos') totalProductos = filas.length;
      if (tabla == 'clientes') {
        totalClientes = filas.length;
        for (final c in filas) {
          totalDeudaCalle += (c['saldo_actual'] as num?)?.toDouble() ?? 0.0;
        }
      }
      if (tabla == 'ventas') totalVentas = filas.length;
      if (tabla == 'categorias') totalCategorias = filas.length;
      if (tabla == 'proveedores') totalProveedores = filas.length;
    }

    final ahora = DateTime.now();
    final fechaStr = '${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}_'
        '${ahora.hour.toString().padLeft(2, '0')}${ahora.minute.toString().padLeft(2, '0')}';

    // 3. Estructurar el paquete de respaldo
    final paqueteRespaldo = {
      'licorpos_version': versionFormato,
      'app': 'LicorPOS',
      'fecha_generacion': ahora.toIso8601String(),
      'configuraciones': {
        'es_modo_oscuro': esModoOscuro,
      },
      'resumen': {
        'total_tablas': tablas.length,
        'total_registros': totalRegistros,
        'total_productos': totalProductos,
        'total_clientes': totalClientes,
        'total_ventas': totalVentas,
        'total_categorias': totalCategorias,
        'total_proveedores': totalProveedores,
        'total_deuda_calle': totalDeudaCalle,
      },
      'datos': datosTablas,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(paqueteRespaldo);

    // 4. Guardar en archivo temporal para compartir
    final tempDir = await getTemporaryDirectory();
    final nombreArchivo = 'licorpos_respaldo_$fechaStr.json';
    final archivo = File('${tempDir.path}/$nombreArchivo');
    await archivo.writeAsString(jsonString, flush: true);

    // 5. Abrir sábana nativa para compartir (WhatsApp, Drive, Gmail, etc.)
    final xFile = XFile(archivo.path, mimeType: 'application/json', name: nombreArchivo);
    await Share.shareXFiles(
      [xFile],
      subject: 'Copia de Seguridad LicorPOS ($fechaStr)',
      text: 'Respaldo completo de LicorPOS generado el ${ahora.day}/${ahora.month}/${ahora.year} '
          'con $totalProductos productos, $totalClientes clientes y $totalVentas ventas registradas.',
    );

    return {
      'ruta': archivo.path,
      'nombre_archivo': nombreArchivo,
      'total_productos': totalProductos,
      'total_clientes': totalClientes,
      'total_ventas': totalVentas,
      'total_deuda': totalDeudaCalle,
      'tamano_kb': (archivo.lengthSync() / 1024).toStringAsFixed(1),
    };
  }

  /// Permite al usuario seleccionar un archivo de respaldo desde su almacenamiento
  Future<String?> seleccionarArchivoRespaldo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'licorpos'],
    );
    if (resultado != null && resultado.files.single.path != null) {
      return resultado.files.single.path;
    }
    return null;
  }

  /// Analiza el archivo de respaldo sin modificar la base de datos para mostrar un preview seguro
  Future<Map<String, dynamic>> analizarArchivoRespaldo(String rutaArchivo) async {
    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) {
      throw Exception('El archivo de respaldo no existe en la ruta especificada.');
    }

    final contenido = await archivo.readAsString();
    final dynamic decoded = jsonDecode(contenido);

    if (decoded is! Map<String, dynamic> || !decoded.containsKey('licorpos_version')) {
      throw Exception('El archivo seleccionado no es una copia de seguridad válida de LicorPOS.');
    }

    final resumen = decoded['resumen'] as Map<String, dynamic>? ?? {};
    final fechaGenStr = decoded['fecha_generacion'] as String?;
    DateTime? fechaGen;
    if (fechaGenStr != null) {
      fechaGen = DateTime.tryParse(fechaGenStr);
    }

    final datos = decoded['datos'] as Map<String, dynamic>? ?? {};

    return {
      'valido': true,
      'fecha_generacion': fechaGen,
      'version': decoded['licorpos_version'],
      'total_productos': resumen['total_productos'] ?? (datos['productos'] as List?)?.length ?? 0,
      'total_clientes': resumen['total_clientes'] ?? (datos['clientes'] as List?)?.length ?? 0,
      'total_ventas': resumen['total_ventas'] ?? (datos['ventas'] as List?)?.length ?? 0,
      'total_categorias': resumen['total_categorias'] ?? (datos['categorias'] as List?)?.length ?? 0,
      'total_proveedores': resumen['total_proveedores'] ?? (datos['proveedores'] as List?)?.length ?? 0,
      'total_deuda_calle': (resumen['total_deuda_calle'] as num?)?.toDouble() ?? 0.0,
      'tamano_kb': (archivo.lengthSync() / 1024).toStringAsFixed(1),
    };
  }

  /// Restaura la base de datos completa de forma transaccional y atómica.
  /// Si algo falla, hace rollback automático.
  Future<void> restaurarRespaldo(String rutaArchivo) async {
    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) {
      throw Exception('El archivo de respaldo no existe.');
    }

    final contenido = await archivo.readAsString();
    final dynamic decoded = jsonDecode(contenido);

    if (decoded is! Map<String, dynamic> || !decoded.containsKey('datos')) {
      throw Exception('Estructura de copia de seguridad inválida.');
    }

    final datos = decoded['datos'] as Map<String, dynamic>;
    final db = await AppDatabase.instance.database;

    // Ejecutamos toda la restauración dentro de una transacción atómica
    await db.transaction((txn) async {
      // 1. Guardar y desactivar triggers temporalmente para permitir limpieza e inserción limpia
      final triggers = await txn.rawQuery("SELECT name, sql FROM sqlite_master WHERE type='trigger'");
      for (final t in triggers) {
        final name = t['name'] as String;
        await txn.execute('DROP TRIGGER IF EXISTS $name');
      }

      // 2. Desactivar llaves foráneas para evitar conflictos de orden de eliminación
      await txn.execute('PRAGMA foreign_keys = OFF');

      try {
        // 3. Obtener tablas existentes y limpiarlas
        final tablasExistentes = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
        );
        final nombresTablas = tablasExistentes.map((t) => t['name'] as String).toSet();

        for (final tabla in nombresTablas) {
          await txn.delete(tabla);
        }

        // 4. Insertar los registros del respaldo en cada tabla correspondiente
        for (final entry in datos.entries) {
          final nombreTabla = entry.key;
          final filas = entry.value;

          if (nombresTablas.contains(nombreTabla) && filas is List) {
            final batch = txn.batch();
            for (final f in filas) {
              if (f is Map<String, dynamic>) {
                batch.insert(nombreTabla, f);
              }
            }
            await batch.commit(noResult: true);
          }
        }
      } finally {
        // 5. Restaurar triggers originales
        for (final t in triggers) {
          final sql = t['sql'] as String?;
          if (sql != null && sql.isNotEmpty) {
            try {
              await txn.execute(sql);
            } catch (e) {
              debugPrint('Error recreando trigger ${t['name']}: $e');
            }
          }
        }

        // 6. Reactivar llaves foráneas
        await txn.execute('PRAGMA foreign_keys = ON');
      }
    });
  }

  /// Analiza un archivo de respaldo para determinar las diferencias de catálogo y precios
  /// sin alterar la base de datos local.
  Future<Map<String, dynamic>> analizarFusionCatalogo(String rutaArchivo) async {
    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) {
      throw Exception('El archivo de respaldo no existe.');
    }

    final contenido = await archivo.readAsString();
    final dynamic decoded = jsonDecode(contenido);

    if (decoded is! Map<String, dynamic> || !decoded.containsKey('datos')) {
      throw Exception('Estructura de respaldo no válida para fusionar catálogo.');
    }

    final datos = decoded['datos'] as Map<String, dynamic>;
    final productosArchivo = (datos['productos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final categoriasArchivo = (datos['categorias'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (productosArchivo.isEmpty) {
      throw Exception('El archivo no contiene productos para actualizar.');
    }

    final db = await AppDatabase.instance.database;

    // Cargar productos y categorías locales actuales
    final productosLocales = await db.query('productos');
    final categoriasLocales = await db.query('categorias');

    final localesPorId = <String, Map<String, dynamic>>{};
    final localesPorCodigo = <String, Map<String, dynamic>>{};
    final categoriasLocalesIds = categoriasLocales.map((c) => c['id'].toString()).toSet();

    for (final p in productosLocales) {
      localesPorId[p['id'].toString()] = p;
      final cb = p['codigo_barras']?.toString().trim();
      if (cb != null && cb.isNotEmpty) {
        localesPorCodigo[cb] = p;
      }
    }

    int productosNuevos = 0;
    int preciosModificados = 0;
    int productosSinCambio = 0;
    final List<Map<String, dynamic>> listaPreciosCambiados = [];

    for (final pArchivo in productosArchivo) {
      final id = pArchivo['id']?.toString();
      final codigo = pArchivo['codigo_barras']?.toString().trim();

      Map<String, dynamic>? matchLocal;
      if (codigo != null && codigo.isNotEmpty && localesPorCodigo.containsKey(codigo)) {
        matchLocal = localesPorCodigo[codigo];
      } else if (id != null && localesPorId.containsKey(id)) {
        matchLocal = localesPorId[id];
      }

      if (matchLocal == null) {
        productosNuevos++;
      } else {
        final precioVentaLocal = (matchLocal['precio_venta'] as num?)?.toDouble() ?? 0.0;
        final precioVentaArchivo = (pArchivo['precio_venta'] as num?)?.toDouble() ?? 0.0;
        final precioCajaLocal = (matchLocal['precio_empaque_mayorista'] as num?)?.toDouble() ?? 0.0;
        final precioCajaArchivo = (pArchivo['precio_empaque_mayorista'] as num?)?.toDouble() ?? 0.0;
        final precioSueltoLocal = (matchLocal['precio_venta_suelta'] as num?)?.toDouble() ?? 0.0;
        final precioSueltoArchivo = (pArchivo['precio_venta_suelta'] as num?)?.toDouble() ?? 0.0;

        final cambioPrecio = (precioVentaLocal != precioVentaArchivo) ||
            (precioCajaLocal != precioCajaArchivo) ||
            (precioSueltoLocal != precioSueltoArchivo);

        if (cambioPrecio) {
          preciosModificados++;
          if (listaPreciosCambiados.length < 8) {
            listaPreciosCambiados.add({
              'nombre': pArchivo['nombre'] ?? 'Sin nombre',
              'precio_anterior': precioVentaLocal,
              'precio_nuevo': precioVentaArchivo,
            });
          }
        } else {
          productosSinCambio++;
        }
      }
    }

    int categoriasNuevas = 0;
    for (final c in categoriasArchivo) {
      final cid = c['id']?.toString();
      if (cid != null && !categoriasLocalesIds.contains(cid)) {
        categoriasNuevas++;
      }
    }

    return {
      'total_productos_archivo': productosArchivo.length,
      'productos_nuevos': productosNuevos,
      'precios_modificados': preciosModificados,
      'productos_sin_cambio': productosSinCambio,
      'categorias_nuevas': categoriasNuevas,
      'muestras_cambios': listaPreciosCambiados,
    };
  }

  /// Ejecuta la fusión inteligente de catálogo y precios:
  /// Actualiza precios y crea nuevos productos SIN TOCAR ventas, caja ni fiados.
  Future<Map<String, int>> ejecutarFusionCatalogo({
    required String rutaArchivo,
    required bool mantenerStockLocal,
  }) async {
    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) throw Exception('El archivo de respaldo no existe.');

    final contenido = await archivo.readAsString();
    final dynamic decoded = jsonDecode(contenido);

    if (decoded is! Map<String, dynamic> || !decoded.containsKey('datos')) {
      throw Exception('Estructura de archivo inválida.');
    }

    final datos = decoded['datos'] as Map<String, dynamic>;
    final productosArchivo = (datos['productos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final categoriasArchivo = (datos['categorias'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final db = await AppDatabase.instance.database;

    int actualizados = 0;
    int creados = 0;
    int categoriasCreadas = 0;

    await db.transaction((txn) async {
      // 1. Categorías: Insertar nuevas o actualizar datos
      final categoriasLocales = await txn.query('categorias');
      final categoriasLocalesIds = categoriasLocales.map((c) => c['id'].toString()).toSet();

      for (final c in categoriasArchivo) {
        final cid = c['id']?.toString();
        if (cid != null && !categoriasLocalesIds.contains(cid)) {
          await txn.insert('categorias', c);
          categoriasCreadas++;
          categoriasLocalesIds.add(cid);
        } else if (cid != null) {
          final mapUpdate = Map<String, dynamic>.from(c)..remove('id');
          await txn.update('categorias', mapUpdate, where: 'id = ?', whereArgs: [cid]);
        }
      }

      // 2. Mapear productos locales por código y por id
      final productosLocales = await txn.query('productos');
      final localesPorId = <String, Map<String, dynamic>>{};
      final localesPorCodigo = <String, Map<String, dynamic>>{};

      for (final p in productosLocales) {
        localesPorId[p['id'].toString()] = p;
        final cb = p['codigo_barras']?.toString().trim();
        if (cb != null && cb.isNotEmpty) {
          localesPorCodigo[cb] = p;
        }
      }

      // 3. Smart Upsert de productos
      final ahora = DateTime.now().toIso8601String();

      for (final p in productosArchivo) {
        final id = p['id']?.toString();
        final codigo = p['codigo_barras']?.toString().trim();

        Map<String, dynamic>? matchLocal;
        if (codigo != null && codigo.isNotEmpty && localesPorCodigo.containsKey(codigo)) {
          matchLocal = localesPorCodigo[codigo];
        } else if (id != null && localesPorId.containsKey(id)) {
          matchLocal = localesPorId[id];
        }

        if (matchLocal == null) {
          // Producto nuevo: insertar completamente
          final nuevoProd = Map<String, dynamic>.from(p);
          nuevoProd['created_at'] = ahora;
          nuevoProd['updated_at'] = ahora;
          await txn.insert('productos', nuevoProd);
          creados++;
        } else {
          // Producto existente: Actualizar solo precios y catálogo
          final localId = matchLocal['id'];
          final camposActualizar = <String, dynamic>{
            'nombre': p['nombre'],
            'descripcion': p['descripcion'],
            'categoria': p['categoria'],
            'subcategoria': p['subcategoria'],
            'tipo_unidad': p['tipo_unidad'] ?? 'UNIDAD',
            'stock_minimo': p['stock_minimo'] ?? 0,
            'costo_mayorista': p['costo_mayorista'] ?? 0,
            'precio_venta': p['precio_venta'] ?? 0,
            'tipo_empaque': p['tipo_empaque'] ?? 'UNIDAD',
            'unidades_por_empaque': p['unidades_por_empaque'] ?? 1,
            'costo_por_empaque': p['costo_por_empaque'] ?? 0,
            'precio_empaque_mayorista': p['precio_empaque_mayorista'],
            'permite_venta_suelta': p['permite_venta_suelta'] ?? 0,
            'nombre_unidad_suelta': p['nombre_unidad_suelta'] ?? 'unidad',
            'unidades_en_empaque_venta': p['unidades_en_empaque_venta'] ?? 1,
            'precio_venta_suelta': p['precio_venta_suelta'] ?? 0,
            'estado_activo': p['estado_activo'] ?? 1,
            'updated_at': ahora,
          };

          if (p['codigo_barras'] != null && (p['codigo_barras'] as String).isNotEmpty) {
            camposActualizar['codigo_barras'] = p['codigo_barras'];
          }
          if (p['imagen_path'] != null) {
            camposActualizar['imagen_path'] = p['imagen_path'];
          }
          if (p['proveedor_id'] != null) {
            camposActualizar['proveedor_id'] = p['proveedor_id'];
          }

          // Si NO se mantiene el stock local, actualizar también stock_actual
          if (!mantenerStockLocal && p.containsKey('stock_actual')) {
            camposActualizar['stock_actual'] = p['stock_actual'];
          }

          await txn.update('productos', camposActualizar, where: 'id = ?', whereArgs: [localId]);
          actualizados++;
        }
      }
    });

    return {
      'actualizados': actualizados,
      'creados': creados,
      'categorias_creadas': categoriasCreadas,
    };
  }

  /// Exporta el catálogo de productos a un archivo CSV compatible con Excel
  Future<String> exportarCatalogoCsv() async {
    final db = await AppDatabase.instance.database;
    final productos = await db.query('productos', where: 'estado_activo = 1', orderBy: 'categoria, nombre ASC');

    final buffer = StringBuffer();
    // Cabecera CSV
    buffer.writeln('Código,Nombre del Producto,Categoría,Marca / Subcategoría,Precio Venta Unidad,Costo Mayorista,Stock Actual,Stock Mínimo,Tipo Empaque,Unidades por Empaque,Precio Empaque Mayorista,Venta Suelta,Precio Venta Suelta');

    for (final p in productos) {
      final codigo = _sanitizarCsv(p['codigo_barras']?.toString() ?? '');
      final nombre = _sanitizarCsv(p['nombre']?.toString() ?? '');
      final categoria = _sanitizarCsv(p['categoria']?.toString() ?? '');
      final subcategoria = _sanitizarCsv(p['subcategoria']?.toString() ?? '');
      final precioVenta = (p['precio_venta'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final costo = (p['costo_mayorista'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final stockActual = (p['stock_actual'] as num?)?.toString() ?? '0';
      final stockMinimo = (p['stock_minimo'] as num?)?.toString() ?? '0';
      final tipoEmpaque = _sanitizarCsv(p['tipo_empaque']?.toString() ?? 'UNIDAD');
      final unidadesEmpaque = (p['unidades_por_empaque'] as num?)?.toString() ?? '1';
      final precioEmpaque = (p['precio_empaque_mayorista'] as num?)?.toStringAsFixed(2) ?? '';
      final ventaSuelta = (p['permite_venta_suelta'] == 1) ? 'SÍ' : 'NO';
      final precioSuelta = (p['precio_venta_suelta'] as num?)?.toStringAsFixed(2) ?? '';

      buffer.writeln('$codigo,$nombre,$categoria,$subcategoria,$precioVenta,$costo,$stockActual,$stockMinimo,$tipoEmpaque,$unidadesEmpaque,$precioEmpaque,$ventaSuelta,$precioSuelta');
    }

    final ahora = DateTime.now();
    final fechaStr = '${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}';
    final tempDir = await getTemporaryDirectory();
    final nombreArchivo = 'catalogo_licorpos_$fechaStr.csv';
    final archivo = File('${tempDir.path}/$nombreArchivo');
    await archivo.writeAsString(buffer.toString(), flush: true);

    final xFile = XFile(archivo.path, mimeType: 'text/csv', name: nombreArchivo);
    await Share.shareXFiles(
      [xFile],
      subject: 'Catálogo de Productos LicorPOS ($fechaStr)',
      text: 'Catálogo de productos exportado desde LicorPOS con ${productos.length} artículos.',
    );

    return archivo.path;
  }

  static String _sanitizarCsv(String valor) {
    if (valor.contains(',') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }
}
