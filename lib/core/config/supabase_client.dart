import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://bsmhpkllamcotbfmjwed.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzbWhwa2xsYW1jb3RiZm1qd2VkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAyODU4OTEsImV4cCI6MjEwNTg2MTg5MX0.2pv3g-w6gj1OgesVsm89P40liJ414vD-WTungBJATGI';

  /// Tenant por defecto para el entorno demo y de desarrollo
  static const String defaultTenantId = '00000000-0000-0000-0000-000000000000';

  /// Inicialización global del cliente de Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  /// Instancia global de SupabaseClient para consultas en repositorios
  static SupabaseClient get client => Supabase.instance.client;
}
