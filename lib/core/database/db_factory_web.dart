import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Motor SQLite en WebAssembly para pruebas en el navegador (Chrome / Edge).
/// Los datos se guardan en el almacenamiento del navegador (IndexedDB).
DatabaseFactory obtenerDatabaseFactory() => databaseFactoryFfiWeb;

/// En web no hay sistema de archivos: basta con el nombre.
Future<String> obtenerRutaBaseDatos(String nombreArchivo) async => nombreArchivo;
