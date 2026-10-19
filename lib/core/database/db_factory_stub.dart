import 'package:sqflite_common/sqlite_api.dart';

/// Implementación vacía: solo se usa si la plataforma no es IO ni Web.
DatabaseFactory obtenerDatabaseFactory() {
  throw UnsupportedError('Plataforma no soportada para la base de datos local.');
}

Future<String> obtenerRutaBaseDatos(String nombreArchivo) {
  throw UnsupportedError('Plataforma no soportada para la base de datos local.');
}
