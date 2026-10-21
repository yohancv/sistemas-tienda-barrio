import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/db_factory.dart';

/// Modelo de métricas de la base de datos local para el Centro de Respaldos
class ResumenBaseDatos {
  final int totalProductos;
  final int totalClientes;
  final int totalCategorias;
  final int totalProveedores;
  final int totalVentas;
  final double totalDeudaCalle;
  final double tamanoDbKb;

  const ResumenBaseDatos({
    required this.totalProductos,
    required this.totalClientes,
    required this.totalCategorias,
    required this.totalProveedores,
    required this.totalVentas,
    required this.totalDeudaCalle,
    required this.tamanoDbKb,
  });
}

/// Provider que calcula las métricas actuales de SQLite
final resumenBaseDatosProvider = FutureProvider<ResumenBaseDatos>((ref) async {
  final db = await AppDatabase.instance.database;

  // Conteo de productos
  final prodCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM productos WHERE estado_activo = 1'),
      ) ??
      0;

  // Conteo de categorías
  final catCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM categorias'),
      ) ??
      0;

  // Conteo de clientes y deuda en la calle
  final cliCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM clientes WHERE activo = 1'),
      ) ??
      0;

  final deudaResult = await db.rawQuery('SELECT SUM(saldo_actual) as total FROM clientes WHERE activo = 1');
  final totalDeuda = (deudaResult.first['total'] as num?)?.toDouble() ?? 0.0;

  // Conteo de proveedores
  final provCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM proveedores WHERE activo = 1'),
      ) ??
      0;

  // Conteo de ventas
  final ventasCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ventas'),
      ) ??
      0;

  // Tamaño físico de la base de datos
  double tamanoKb = 0.0;
  try {
    final ruta = await obtenerRutaBaseDatos(AppConfig.nombreBaseDatos);
    final file = File(ruta);
    if (file.existsSync()) {
      tamanoKb = file.lengthSync() / 1024.0;
    }
  } catch (_) {}

  return ResumenBaseDatos(
    totalProductos: prodCount,
    totalClientes: cliCount,
    totalCategorias: catCount,
    totalProveedores: provCount,
    totalVentas: ventasCount,
    totalDeudaCalle: totalDeuda,
    tamanoDbKb: tamanoKb,
  );
});
