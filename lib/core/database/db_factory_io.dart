import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite_movil;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool get _esEscritorio =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Devuelve el motor SQLite adecuado para móvil o escritorio.
DatabaseFactory obtenerDatabaseFactory() {
  if (_esEscritorio) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return sqflite_movil.databaseFactory;
}

/// Ruta completa del archivo de base de datos dentro del almacenamiento privado de la app.
Future<String> obtenerRutaBaseDatos(String nombreArchivo) async {
  if (_esEscritorio) {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, nombreArchivo);
  }
  final dirBases = await sqflite_movil.getDatabasesPath();
  return p.join(dirBases, nombreArchivo);
}
