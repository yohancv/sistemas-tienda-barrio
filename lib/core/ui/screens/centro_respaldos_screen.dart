import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../inventario/state/providers/categorias_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../backup/backup_providers.dart';
import '../../backup/backup_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../utils/app_haptics.dart';

/// Pantalla del Centro de Respaldos y Exportación / Importación de Datos
/// 100% compatible con Pure Clean Retail (Claro) y Modern Slate Fintech (Oscuro).
class CentroRespaldosScreen extends ConsumerStatefulWidget {
  const CentroRespaldosScreen({super.key});

  @override
  ConsumerState<CentroRespaldosScreen> createState() => _CentroRespaldosScreenState();
}

class _CentroRespaldosScreenState extends ConsumerState<CentroRespaldosScreen> {
  bool _exportando = false;
  bool _restaurando = false;
  bool _fusionando = false;
  bool _exportandoCsv = false;

  @override
  Widget build(BuildContext context) {
    final esOscuro = ref.watch(esModoOscuroProvider);
    final resumenAsync = ref.watch(resumenBaseDatosProvider);

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Copias de Seguridad & Datos',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Banner explicativo superior
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: esOscuro
                      ? const [AppColors.darkBannerStart, AppColors.darkBannerEnd]
                      : const [AppColors.bannerFiadosStart, AppColors.bannerFiadosEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: esOscuro ? AppColors.darkAccent.withAlpha(80) : const Color(0xFF334155),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: esOscuro
                          ? AppColors.darkAccent.withAlpha(35)
                          : Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: esOscuro ? AppColors.darkAccent : Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TUS DATOS SON 100% TUYOS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Toda tu tienda vive en tu teléfono sin costo de nube. Exporta respaldos para cambiar de móvil sin perder nada.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Tarjeta resumen actual de la tienda
            resumenAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => const SizedBox.shrink(),
              data: (resumen) => _buildResumenCard(resumen, esOscuro, surfaceColor, cardBorder, textPrimary, textSecondary),
            ),

            const SizedBox(height: 16),

            // 3. Tarjeta de Exportación Completa
            _buildCardExportar(esOscuro, surfaceColor, cardBorder, textPrimary, textSecondary, textMuted),

            const SizedBox(height: 16),

            // 4. Tarjeta de Fusión Inteligente: Actualizar Solo Precios y Catálogo
            _buildCardFusionPrecios(esOscuro, surfaceColor, cardBorder, textPrimary, textSecondary, textMuted),

            const SizedBox(height: 16),

            // 5. Tarjeta de Restauración Completa
            _buildCardRestaurar(esOscuro, surfaceColor, cardBorder, textPrimary, textSecondary, textMuted),

            const SizedBox(height: 16),

            // 6. Tarjeta de Exportación a Excel (CSV)
            _buildCardExcelCsv(esOscuro, surfaceColor, cardBorder, textPrimary, textSecondary, textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard(
    ResumenBaseDatos resumen,
    bool esOscuro,
    Color surfaceColor,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estado Actual de la Base Local',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esOscuro ? AppColors.darkSurfaceMuted : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${resumen.tamanoDbKb.toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniKpi('🍾 Productos', '${resumen.totalProductos}', esOscuro),
              const SizedBox(width: 8),
              _buildMiniKpi('🏷️ Categorías', '${resumen.totalCategorias}', esOscuro),
              const SizedBox(width: 8),
              _buildMiniKpi('👥 Clientes', '${resumen.totalClientes}', esOscuro),
              const SizedBox(width: 8),
              _buildMiniKpi('🧾 Ventas', '${resumen.totalVentas}', esOscuro),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(String label, String valor, bool esOscuro) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: esOscuro ? AppColors.darkBackground : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: esOscuro ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardExportar(
    bool esOscuro,
    Color surfaceColor,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (esOscuro ? AppColors.darkAccent : AppColors.primary).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: esOscuro ? AppColors.darkAccent : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Crear Copia de Seguridad Completa',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      'Exporta el 100% de productos, precios, deudas y ventas.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: esOscuro ? AppColors.darkAccent : AppColors.primary,
                foregroundColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _exportando ? null : _ejecutarExportacion,
              icon: _exportando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_rounded, size: 20),
              label: Text(
                _exportando ? 'GENERANDO ARCHIVO...' : 'CREAR & COMPARTIR RESPALDO',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFusionPrecios(
    bool esOscuro,
    Color surfaceColor,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    const accentCyan = Color(0xFF0EA5E9);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esOscuro ? accentCyan.withAlpha(70) : accentCyan.withAlpha(50),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentCyan.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.price_change_rounded,
                  color: accentCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Actualizar Solo Precios y Catálogo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sincroniza precios y productos nuevos enviados desde otro móvil.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Badge protector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(40)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '100% Seguro: Ventas del día, dinero en caja y fiados quedan intactos.',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _fusionando ? null : _ejecutarSeleccionYFusion,
              icon: _fusionando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_alt_rounded, size: 20),
              label: Text(
                _fusionando ? 'FUSIONANDO PRECIOS...' : 'ACTUALIZAR PRECIOS DESDE ARCHIVO',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardRestaurar(
    bool esOscuro,
    Color surfaceColor,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (esOscuro ? AppColors.darkSuccess : AppColors.success).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: esOscuro ? AppColors.darkSuccess : AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Restauración Completa (Todo el Sistema)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      'Sobrescribe todo. Ideal para cambio de teléfono.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: esOscuro ? AppColors.darkSuccess : AppColors.success,
                foregroundColor: esOscuro ? AppColors.darkSuccessDark : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _restaurando ? null : _ejecutarSeleccionYRestauracion,
              icon: _restaurando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_open_rounded, size: 20),
              label: Text(
                _restaurando ? 'RESTAURANDO BASE DE DATOS...' : 'SELECCIONAR ARCHIVO COMPLETO (.JSON)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardExcelCsv(
    bool esOscuro,
    Color surfaceColor,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_view_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4. Exportar Catálogo a Excel (CSV)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      'Genera una hoja de cálculo con tus productos, costos y precios.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary,
                side: BorderSide(color: cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _exportandoCsv ? null : _ejecutarExportacionCsv,
              icon: _exportandoCsv
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_outlined, size: 18),
              label: Text(
                _exportandoCsv ? 'GENERANDO CSV...' : 'EXPORTAR CATÁLOGO A EXCEL (.CSV)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE EXPORTACIÓN ---
  Future<void> _ejecutarExportacion() async {
    setState(() => _exportando = true);
    AppHaptics.medium();

    try {
      final esOscuro = ref.read(esModoOscuroProvider);
      final resultado = await BackupService.instance.exportarYCompartirRespaldo(esModoOscuro: esOscuro);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Copia generada con éxito (${resultado['total_productos']} productos guardados).',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error al exportar respaldo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // --- LÓGICA DE SELECCIÓN Y RESTAURACIÓN ---
  Future<void> _ejecutarSeleccionYRestauracion() async {
    AppHaptics.selection();
    try {
      final ruta = await BackupService.instance.seleccionarArchivoRespaldo();
      if (ruta == null || !mounted) return;

      // 1. Analizar el archivo para mostrar preview previo
      final preview = await BackupService.instance.analizarArchivoRespaldo(ruta);

      if (!mounted) return;

      // 2. Mostrar diálogo modal interactivo con detalle de confirmación
      final bool? confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildDialogConfirmacionRestauracion(ctx, preview),
      );

      if (confirmar != true || !mounted) return;

      // 3. Ejecutar restauración atómica
      setState(() => _restaurando = true);
      AppHaptics.heavy();

      await BackupService.instance.restaurarRespaldo(ruta);

      // 4. Invalidar todos los providers de Riverpod para refrescar la app completa en vivo
      ref.invalidate(productosListProvider);
      ref.invalidate(clientesListProvider);
      ref.invalidate(conteoDeudoresProvider);
      ref.invalidate(arbolCategoriasProvider);
      ref.invalidate(resumenBaseDatosProvider);
      ref.invalidate(cajaTurnoActivaProvider);
      ref.invalidate(resumenCajaTurnoProvider);

      if (mounted) {
        AppHaptics.success();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 10),
                Text('Restauración Exitosa', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Se han restaurado correctamente ${preview['total_productos']} productos, '
              '${preview['total_categorias']} categorías y ${preview['total_clientes']} clientes.\n\n'
              'Tu catálogo y datos están 100% listos para operar.',
              style: const TextStyle(fontSize: 14.5, height: 1.4),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Comenzar a Vender'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.danger),
                SizedBox(width: 10),
                Text('Error de Restauración'),
              ],
            ),
            content: Text(
              'No se pudo completar la restauración: $e\n\n'
              'La base de datos se mantuvo intacta gracias al rollback de seguridad.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  // --- LÓGICA DE FUSIÓN INTELIGENTE (SOLO PRECIOS Y CATÁLOGO) ---
  Future<void> _ejecutarSeleccionYFusion() async {
    AppHaptics.selection();
    try {
      final ruta = await BackupService.instance.seleccionarArchivoRespaldo();
      if (ruta == null || !mounted) return;

      // 1. Analizar diferencias en el catálogo sin tocar la base local
      final preview = await BackupService.instance.analizarFusionCatalogo(ruta);
      if (!mounted) return;

      bool mantenerStock = true;

      // 2. Diálogo modal interactivo con preview de precios y opción de stock
      final bool? confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            final esOscuroDialog = ref.read(esModoOscuroProvider);
            final muestras = (preview['muestras_cambios'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.price_change_rounded, color: Color(0xFF0EA5E9), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Actualizar Precios y Catálogo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge de protección
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cero riesgo: Tus ventas de hoy, dinero en caja y clientes con fiado NO serán tocados.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Resumen de cambios detectados
                    Text(
                      'Resumen de cambios detectados:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: esOscuroDialog ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esOscuroDialog ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: esOscuroDialog ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.trending_up_rounded, color: Color(0xFF0EA5E9), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${preview['precios_modificados']} productos cambiarán de precio',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${preview['productos_nuevos']} productos nuevos se añadirán',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          if ((preview['categorias_nuevas'] as int? ?? 0) > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.category_rounded, color: Color(0xFFFFB800), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${preview['categorias_nuevas']} categorías nuevas a registrar',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.check_rounded, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${preview['productos_sin_cambio']} productos sin modificaciones',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Muestra de precios cambiados si hay
                    if (muestras.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Ejemplos de variación de precios:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      ...muestras.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m['nombre'],
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Bs ${m['precio_anterior']} ➔ ',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  'Bs ${m['precio_nuevo']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    const SizedBox(height: 14),

                    // Selector de inventario/stock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: esOscuroDialog ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: esOscuroDialog ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: mantenerStock,
                            activeColor: const Color(0xFF0EA5E9),
                            onChanged: (val) {
                              setDialogState(() {
                                mantenerStock = val ?? true;
                              });
                            },
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mantener stock contado en este móvil',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  'Recomendado para no alterar tu inventario físico de ventas.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('APLICAR PRECIOS'),
                ),
              ],
            );
          },
        ),
      );

      if (confirmar != true || !mounted) return;

      // 3. Ejecutar Fusión en SQLite
      setState(() => _fusionando = true);
      AppHaptics.heavy();

      final resultado = await BackupService.instance.ejecutarFusionCatalogo(
        rutaArchivo: ruta,
        mantenerStockLocal: mantenerStock,
      );

      // 4. Invalidar providers de Riverpod para actualizar POS y catálogo en vivo
      ref.invalidate(productosListProvider);
      ref.invalidate(arbolCategoriasProvider);
      ref.invalidate(resumenBaseDatosProvider);

      if (mounted) {
        AppHaptics.success();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF0EA5E9), size: 28),
                SizedBox(width: 10),
                Text('Precios Sincronizados', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Se actualizaron exitosamente:\n\n'
              '• ${resultado['actualizados']} productos con sus nuevos precios y datos.\n'
              '• ${resultado['creados']} productos nuevos añadidos al catálogo.\n'
              '• ${resultado['categorias_creadas']} categorías nuevas registradas.\n\n'
              '🛡️ Todas tus ventas del día, dinero en caja y fiados de clientes permanecen 100% intactos.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Comenzar a Vender'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.danger),
                SizedBox(width: 10),
                Text('Error de Fusión'),
              ],
            ),
            content: Text(
              'No se pudo actualizar el catálogo: $e\n\n'
              'Tus datos actuales no sufrieron ninguna alteración.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fusionando = false);
    }
  }

  Widget _buildDialogConfirmacionRestauracion(BuildContext ctx, Map<String, dynamic> preview) {
    final DateTime? fechaGen = preview['fecha_generacion'];
    final fechaStr = fechaGen != null
        ? '${fechaGen.day}/${fechaGen.month}/${fechaGen.year} a las ${fechaGen.hour.toString().padLeft(2, '0')}:${fechaGen.minute.toString().padLeft(2, '0')}'
        : 'Fecha no especificada';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
          SizedBox(width: 10),
          Text('Confirmar Restauración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se reemplazarán los datos actuales por el contenido de la copia de seguridad seleccionada:',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 Generado: $fechaStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Text('🍾 ${preview['total_productos']} productos en catálogo', style: const TextStyle(fontSize: 12.5)),
                  Text('🏷️ ${preview['total_categorias']} categorías y marcas', style: const TextStyle(fontSize: 12.5)),
                  Text('👥 ${preview['total_clientes']} clientes y fiados', style: const TextStyle(fontSize: 12.5)),
                  Text('🧾 ${preview['total_ventas']} ventas históricas', style: const TextStyle(fontSize: 12.5)),
                  Text('🚚 ${preview['total_proveedores']} proveedores registrados', style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Asegúrate de que este sea el archivo correcto de tu negocio.',
              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('RESTAURAR AHORA'),
        ),
      ],
    );
  }

  // --- LÓGICA DE EXPORTACIÓN A CSV ---
  Future<void> _ejecutarExportacionCsv() async {
    setState(() => _exportandoCsv = true);
    AppHaptics.selection();
    try {
      await BackupService.instance.exportarCatalogoCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text(
              'Catálogo CSV generado listo para compartir o abrir en Excel.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error al exportar catálogo CSV: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportandoCsv = false);
    }
  }
}
