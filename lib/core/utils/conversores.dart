/// Conversores seguros para leer filas de la base de datos local.
///
/// SQLite no tiene tipo booleano: guarda `1` / `0` en columnas INTEGER.
/// Este helper acepta int, bool o String para que los modelos funcionen
/// igual con datos locales o con datos que vengan de otra fuente.
bool leerBool(dynamic valor, {bool porDefecto = false}) {
  if (valor == null) return porDefecto;
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  if (valor is String) {
    final v = valor.trim().toLowerCase();
    if (v == '1' || v == 'true') return true;
    if (v == '0' || v == 'false') return false;
  }
  return porDefecto;
}
