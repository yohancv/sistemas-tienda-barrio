// Selección de la implementación de SQLite según la plataforma:
// - Android / iOS: plugin nativo `sqflite`.
// - Windows / Linux / macOS: `sqflite_common_ffi` (para desarrollo en PC).
// - Web (Chrome): `sqflite_common_ffi_web` (SQLite compilado a WebAssembly).
export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
