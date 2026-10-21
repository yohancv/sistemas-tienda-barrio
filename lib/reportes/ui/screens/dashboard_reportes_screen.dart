import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../data/models/reporte_financiero_model.dart';
import '../../state/providers/reportes_providers.dart';
import '../../utils/balance_whatsapp_formatter.dart';

class DashboardReportesScreen extends ConsumerWidget {
  const DashboardReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodoActual = ref.watch(filtroPeriodoDashboardProvider);
    final reporteAsync = ref.watch(reporteDashboardProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance & Métricas',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatearPeriodoLegible(periodoActual),
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: textPrimary),
            tooltip: 'Compartir balance por WhatsApp',
            onPressed: () {
              final data = reporteAsync.value;
              if (data != null) {
                BalanceWhatsAppFormatter.compartirBalance(data);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textPrimary),
            tooltip: 'Actualizar métricas',
            onPressed: () => ref.invalidate(reporteDashboardProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reporteDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // 1. Selector de Período
            _buildSelectorPeriodo(context, ref, periodoActual),
            const SizedBox(height: 16),

            // 2. Contenido del Reporte Reactivo
            reporteAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Calculando ganancias y métricas...',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.danger.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                    const SizedBox(height: 10),
                    Text(
                      'Error al cargar métricas: $err',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(reporteDashboardProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (data) => _buildDashboardContenido(context, data),
            ),
          ],
        ),
      ),
    );
  }

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];
  static const _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  String _formatearPeriodoLegible(PeriodoFiltroReporte p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodoFiltroReporte.hoy:
        final diaNom = _diasSemana[now.weekday - 1];
        final mesNom = _meses[now.month - 1];
        return 'Hoy, $diaNom ${now.day} de $mesNom';
      case PeriodoFiltroReporte.estaSemana:
        final haceSiete = now.subtract(const Duration(days: 6));
        final m1 = _mesesCortos[haceSiete.month - 1];
        final m2 = _mesesCortos[now.month - 1];
        return '${haceSiete.day} $m1 - ${now.day} $m2 ${now.year}';
      case PeriodoFiltroReporte.esteMes:
        return '${_meses[now.month - 1]} ${now.year}'.toUpperCase();
    }
  }

  // ==========================================================================
  // 1. SELECTOR DE PERÍODO (Segmented Style)
  // ==========================================================================
  Widget _buildSelectorPeriodo(BuildContext context, WidgetRef ref, PeriodoFiltroReporte periodo) {
    final esOscuro = ref.watch(esModoOscuroProvider);
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildChipPeriodo(
            label: 'Hoy',
            icono: Icons.today_rounded,
            seleccionado: periodo == PeriodoFiltroReporte.hoy,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => ref.read(filtroPeriodoDashboardProvider.notifier).state = PeriodoFiltroReporte.hoy,
          ),
          const SizedBox(width: 4),
          _buildChipPeriodo(
            label: 'Esta Semana',
            icono: Icons.date_range_rounded,
            seleccionado: periodo == PeriodoFiltroReporte.estaSemana,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => ref.read(filtroPeriodoDashboardProvider.notifier).state = PeriodoFiltroReporte.estaSemana,
          ),
          const SizedBox(width: 4),
          _buildChipPeriodo(
            label: 'Este Mes',
            icono: Icons.calendar_month_rounded,
            seleccionado: periodo == PeriodoFiltroReporte.esteMes,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => ref.read(filtroPeriodoDashboardProvider.notifier).state = PeriodoFiltroReporte.esteMes,
          ),
        ],
      ),
    );
  }

  Widget _buildChipPeriodo({
    required String label,
    required IconData icono,
    required bool seleccionado,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.retailBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 16,
                color: seleccionado ? Colors.white : textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? Colors.white : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 2. CONTENIDO PRINCIPAL DEL DASHBOARD
  // ==========================================================================
  Widget _buildDashboardContenido(BuildContext context, DashboardReporteCompleto data) {
    final f = data.financiero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TARJETA HERO: BALANCE DEL NEGOCIO
        _buildHeroGananciaCard(f),
        const SizedBox(height: 12),

        // BOTÓN: COMPARTIR BALANCE POR WHATSAPP
        _buildBotonWhatsApp(context, data),
        const SizedBox(height: 14),

        // TARJETA DE FIADOS (Dinero en la calle) SI HUBO FIADOS
        if (f.ventasFiadas > 0) ...[
          _buildTarjetaFiadosEnLaCalle(f),
          const SizedBox(height: 14),
        ],

        // TARJETA DE ABONOS RECIBIDOS SI HUBO COBROS DE FIADOS
        if (f.totalAbonosCobrados > 0) ...[
          _buildTarjetaAbonosRecibidos(f),
          const SizedBox(height: 14),
        ],

        // TARJETA DE GASTOS OPERATIVOS SI SE REGISTRARON EN CAJA
        if (f.totalGastosTienda > 0) ...[
          _buildTarjetaGastosTienda(f),
          const SizedBox(height: 14),
        ],

        // MEDIOS DE PAGO (EFECTIVO, QR, FIADO)
        _buildMediosPagoGrid(f),
        const SizedBox(height: 20),

        // TOP 5 PRODUCTOS MÁS VENDIDOS
        _buildTopProductosSection(data.topProductos),
        const SizedBox(height: 20),

        // VENTAS POR CATEGORÍA
        if (data.ventasPorCategoria.isNotEmpty) ...[
          _buildCategoriasSection(data.ventasPorCategoria),
          const SizedBox(height: 20),
        ],

        // MERMAS Y CONTROL DE PÉRDIDAS
        if (f.totalMermas > 0) ...[
          _buildMermasCard(f.totalMermas),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  // ==========================================================================
  // TARJETA HERO: BALANCE DEL NEGOCIO (UTILIDAD NETA LIMPIA)
  // ==========================================================================
  Widget _buildHeroGananciaCard(ReporteFinancieroModel f) {
    final bool tieneGanancia = f.esBalancePositivo;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tieneGanancia
              ? [const Color(0xFF064E3B), const Color(0xFF065F46), const Color(0xFF047857)]
              : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (tieneGanancia ? const Color(0xFF047857) : Colors.red).withAlpha(50),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BALANCE DEL NEGOCIO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(70)),
                ),
                child: Text(
                  tieneGanancia ? '🟢 Balance Positivo' : '🔴 Balance en Contra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monto gigante de Utilidad Limpia del Balance
          Text(
            'Bs. ${f.utilidadNetaBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            f.totalCobradoReal > 0
                ? 'Plata real y libre en mano (Total cobrado - Costos de reposición, gastos y mermas).'
                : 'Sin movimientos de dinero registrados en este período.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),

          if (f.gananciaPendienteFiados > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFBBF24), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '+ Bs. ${f.gananciaPendienteFiados.toStringAsFixed(2)} por cobrar en la calle (fiados)',
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Desglose de Dinero Cobrado vs Costos vs Gastos
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Cobrado', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${f.totalCobradoReal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Costo Reposición', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${f.costoMercaderiaCobrada.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gastos / Mermas', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${(f.totalGastosTienda + f.totalMermas).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Atención', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${f.totalTransacciones} / ${f.totalArticulosVendidos}u',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BOTÓN: COMPARTIR BALANCE POR WHATSAPP
  // ==========================================================================
  Widget _buildBotonWhatsApp(BuildContext context, DashboardReporteCompleto data) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withAlpha(50),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final exito = await BalanceWhatsAppFormatter.compartirBalance(data);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  exito
                      ? 'Abriendo WhatsApp con el balance...'
                      : 'Balance copiado al portapapeles para compartir.',
                ),
                backgroundColor: const Color(0xFF1E3A2F),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Compartir Balance por WhatsApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TARJETA DE GASTOS OPERATIVOS DE TIENDA
  // ==========================================================================
  Widget _buildTarjetaGastosTienda(ReporteFinancieroModel f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gastos de Tienda / Operativos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                ),
                Text(
                  'Salidas de caja por luz, bolsas, ayudante, limpieza u otros.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          Text(
            '-Bs. ${f.totalGastosTienda.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TARJETA DE FIADOS DEL PERÍODO (MERCADERÍA EN LA CALLE)
  // ==========================================================================
  Widget _buildTarjetaFiadosEnLaCalle(ReporteFinancieroModel f) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handshake_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiados de este período (En la calle)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'No se cuentan como ganancia en mano hasta que los clientes abonen.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Valor Fiado', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${f.ventasFiadas.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Costo Invertido', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${f.costoMercaderiaFiada.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ganancia al cobrar', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                    const SizedBox(height: 2),
                    Text(
                      'Bs. ${f.gananciaPendienteFiados.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TARJETA DE ABONOS RECIBIDOS (COBRO DE DEUDAS VIEJAS)
  // ==========================================================================
  Widget _buildTarjetaAbonosRecibidos(ReporteFinancieroModel f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.price_check_rounded, color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cobro de Fiados Anteriores (Abonos)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
                Text(
                  'Efectivo: Bs. ${f.totalEfectivoAbonos.toStringAsFixed(2)} | QR: Bs. ${f.totalQrAbonos.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
          Text(
            '+Bs. ${f.totalAbonosCobrados.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DISTRIBUCIÓN DE MEDIOS DE PAGO
  // ==========================================================================
  Widget _buildMediosPagoGrid(ReporteFinancieroModel f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Dinero Físico, Digital y Fiados',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Efectivo
            Expanded(
              child: _buildTarjetaMedioPago(
                titulo: 'Efectivo',
                icono: Icons.money_rounded,
                monto: f.totalDineroEnCaja,
                subtitulo: 'En cajón',
                detalleExtra: f.totalEfectivoAbonos > 0
                    ? '+Bs.${f.totalEfectivoAbonos.toStringAsFixed(0)} abonos'
                    : null,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            // QR
            Expanded(
              child: _buildTarjetaMedioPago(
                titulo: 'Cobros QR',
                icono: Icons.qr_code_scanner_rounded,
                monto: f.totalDineroEnBanco,
                subtitulo: 'En banco',
                detalleExtra: f.totalQrAbonos > 0
                    ? '+Bs.${f.totalQrAbonos.toStringAsFixed(0)} abonos'
                    : null,
                color: const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(width: 10),
            // Fiados
            Expanded(
              child: _buildTarjetaMedioPago(
                titulo: 'Fiados',
                icono: Icons.handshake_outlined,
                monto: f.ventasFiadas,
                subtitulo: 'En la calle',
                detalleExtra: f.gananciaPendienteFiados > 0
                    ? '+Bs.${f.gananciaPendienteFiados.toStringAsFixed(0)} gan.'
                    : null,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTarjetaMedioPago({
    required String titulo,
    required IconData icono,
    required double monto,
    required String subtitulo,
    String? detalleExtra,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, size: 16, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bs. ${monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: monto > 0 ? color : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (detalleExtra != null) ...[
            const SizedBox(height: 4),
            Text(
              detalleExtra,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // TOP 5 PRODUCTOS MÁS VENDIDOS
  // ==========================================================================
  Widget _buildTopProductosSection(List<TopProductoReporteModel> productos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Top 5 Productos Estrella',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Text('Por venta', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          if (productos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'No hay ventas en este período para generar el ranking.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: productos.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final p = productos[index];
                final medalla = index == 0
                    ? '🥇'
                    : index == 1
                        ? '🥈'
                        : index == 2
                            ? '🥉'
                            : '#${index + 1}';

                return Row(
                  children: [
                    // Posición
                    SizedBox(
                      width: 28,
                      child: Text(
                        medalla,
                        style: TextStyle(
                          fontSize: index < 3 ? 18 : 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Icono de Categoría
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(p.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),

                    // Nombre y cantidad vendida
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.cantidadVendida.toStringAsFixed(p.cantidadVendida % 1 == 0 ? 0 : 2)} unidades vendidas',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // Montos: Venta y Ganancia
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Bs. ${p.totalVenta.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '+Bs. ${p.gananciaAportada.toStringAsFixed(2)} ganancia',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // VENTAS POR CATEGORÍA
  // ==========================================================================
  Widget _buildCategoriasSection(List<CategoriaVentaReporteModel> categorias) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Rubros más vendidos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...categorias.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            cat.categoria,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      Text(
                        'Bs. ${cat.totalVenta.toStringAsFixed(2)} (${cat.porcentajeDelTotal.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (cat.porcentajeDelTotal / 100.0).clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceMuted,
                      color: AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================================
  // TARJETA DE MERMAS Y PÉRDIDAS
  // ==========================================================================
  Widget _buildMermasCard(double totalMermas) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.broken_image_outlined, color: AppColors.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pérdidas por Mermas / Bajas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ya descontado de tu ganancia bruta: -Bs. ${totalMermas.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
