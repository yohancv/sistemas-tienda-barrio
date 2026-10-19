import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/caja_turno_model.dart';
import '../../data/models/resumen_caja_model.dart';
import '../../state/providers/caja_providers.dart';
import '../widgets/modal_apertura_caja.dart';
import '../widgets/modal_movimiento_manual.dart';
import '../widgets/dialogo_ticket_arqueo.dart';

class CierreCajaScreen extends ConsumerStatefulWidget {
  const CierreCajaScreen({super.key});

  @override
  ConsumerState<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends ConsumerState<CierreCajaScreen> {
  bool _mostrarEfectivoEstimado = true;
  bool _enModoArqueo = false;
  bool _revelarComparativa = false;
  bool _isProcessingCierre = false;
  final _observacionesController = TextEditingController();

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  void _abrirModalApertura() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalAperturaCaja(),
    );
  }

  void _abrirModalMovimiento(String turnoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalMovimientoManual(turnoId: turnoId),
    );
  }

  Future<void> _ejecutarCierreDefinitivo({
    required CajaTurnoModel turno,
    required ResumenCajaModel resumen,
    required double montoContado,
    required Map<String, int> desglose,
  }) async {
    final double dif = ((montoContado - resumen.montoEsperadoEfectivo) * 100).round() / 100.0;
    final bool estaCuadrada = dif.abs() <= 1.0;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('¿Confirmar Cierre de Caja?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          estaCuadrada
              ? 'Se cerrará el turno con un cuadre perfecto de Bs. ${montoContado.toStringAsFixed(2)}.'
              : 'Se cerrará el turno con una diferencia de ${dif >= 0 ? "+" : ""}Bs. ${dif.toStringAsFixed(2)}.\n¿Deseas finalizar ahora?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver a revisar', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Cerrar Definitivamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isProcessingCierre = true);

    try {
      final turnoCerrado = await ref.read(cajaTurnoActivaProvider.notifier).cerrarTurno(
            montoContado: montoContado,
            resumen: resumen,
            desglose: desglose,
            observaciones: _observacionesController.text.trim(),
          );

      // Reiniciar estado local
      ref.read(conteoCajaProvider.notifier).reiniciar();
      _observacionesController.clear();
      setState(() {
        _enModoArqueo = false;
        _revelarComparativa = false;
        _isProcessingCierre = false;
      });

      if (!mounted) return;

      // Mostrar Ticket de Arqueo
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoTicketArqueo(turno: turnoCerrado),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingCierre = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text('Error al cerrar caja: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final turnoAsync = ref.watch(cajaTurnoActivaProvider);

    return turnoAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Caja')),
        body: Center(child: Text('Error al cargar caja: $e')),
      ),
      data: (turno) {
        if (turno == null) {
          return _VistaCajaCerrada(onAbrirCaja: _abrirModalApertura);
        }

        if (_enModoArqueo) {
          return _VistaArqueoConteo(
            turno: turno,
            revelarComparativa: _revelarComparativa,
            isProcessing: _isProcessingCierre,
            observacionesController: _observacionesController,
            onVolver: () => setState(() {
              _enModoArqueo = false;
              _revelarComparativa = false;
            }),
            onRevelarComparativa: () => setState(() => _revelarComparativa = true),
            onConfirmarCierre: (resumen, montoContado, desglose) {
              _ejecutarCierreDefinitivo(
                turno: turno,
                resumen: resumen,
                montoContado: montoContado,
                desglose: desglose,
              );
            },
          );
        }

        return _VistaCajaAbierta(
          turno: turno,
          mostrarEfectivo: _mostrarEfectivoEstimado,
          onToggleEfectivo: () => setState(() => _mostrarEfectivoEstimado = !_mostrarEfectivoEstimado),
          onRegistrarMovimiento: () => _abrirModalMovimiento(turno.id),
          onIniciarArqueo: () {
            ref.read(conteoCajaProvider.notifier).reiniciar();
            setState(() {
              _enModoArqueo = true;
              _revelarComparativa = false;
            });
          },
        );
      },
    );
  }
}

// ============================================================================
// 1. VISTA CUANDO LA CAJA ESTÁ CERRADA (Hero para abrir turno + historial)
// ============================================================================
class _VistaCajaCerrada extends ConsumerWidget {
  final VoidCallback onAbrirCaja;

  const _VistaCajaCerrada({required this.onAbrirCaja});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Caja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.point_of_sale, size: 60, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No hay Turno de Caja Abierto',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Inicia el turno ingresando el fondo inicial en efectivo (cambio sencillo) para habilitar las ventas y cuadrar el dinero del día.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 36),

              // Botón Masivo Abrir Turno
              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: onAbrirCaja,
                  icon: const Icon(Icons.lock_open, color: Colors.white, size: 28),
                  label: const Text(
                    '➕ ABRIR TURNO DE CAJA',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Sección Historial de Turnos
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Turnos Cerrados Recientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<CajaTurnoModel>>(
                future: ref.read(cajaRepositoryProvider).obtenerHistorialTurnos(SupabaseConfig.defaultTenantId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  }
                  final historial = snapshot.data ?? [];
                  if (historial.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Aún no hay turnos históricos registrados.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historial.length > 5 ? 5 : historial.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = historial[i];
                      final dif = item.diferencia ?? 0.0;
                      final bool esCuadrado = dif.abs() <= 1.0;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => DialogoTicketArqueo(turno: item),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: esCuadrado ? AppColors.success.withAlpha(30) : AppColors.warning.withAlpha(30),
                            child: Icon(
                              esCuadrado ? Icons.check : Icons.warning_amber_rounded,
                              color: esCuadrado ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          title: Text(
                            'Turno del ${item.fechaApertura.day}/${item.fechaApertura.month}/${item.fechaApertura.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Esperado: Bs. ${item.montoEsperadoEfectivo.toStringAsFixed(2)} | Real: Bs. ${(item.montoRealContado ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. VISTA CUANDO LA CAJA ESTÁ ABIERTA (Dashboard financiero en vivo)
// ============================================================================
class _VistaCajaAbierta extends ConsumerWidget {
  final CajaTurnoModel turno;
  final bool mostrarEfectivo;
  final VoidCallback onToggleEfectivo;
  final VoidCallback onRegistrarMovimiento;
  final VoidCallback onIniciarArqueo;

  const _VistaCajaAbierta({
    required this.turno,
    required this.mostrarEfectivo,
    required this.onToggleEfectivo,
    required this.onRegistrarMovimiento,
    required this.onIniciarArqueo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenCajaTurnoProvider);
    final movimientosAsync = ref.watch(movimientosCajaTurnoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turno de Caja Activo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
            tooltip: 'Refrescar montos',
            onPressed: () {
              ref.invalidate(resumenCajaTurnoProvider);
              ref.invalidate(movimientosCajaTurnoProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado de Turno
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: AppColors.success),
                          SizedBox(width: 6),
                          Text('ABIERTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iniciado a las ${turno.fechaApertura.hour.toString().padLeft(2, '0')}:${turno.fechaApertura.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Fondo inicial: Bs. ${turno.montoInicial.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tarjetas Métricas
              resumenAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Center(child: Text('Error al calcular resumen: $e')),
                data: (resumen) {
                  final r = resumen ?? ResumenCajaModel(
                    turnoId: turno.id,
                    estado: 'ABIERTA',
                    fechaApertura: turno.fechaApertura,
                    montoInicial: turno.montoInicial,
                    totalVentasEfectivo: 0,
                    totalVentasQr: 0,
                    totalFiadosOtorgados: 0,
                    totalFiadosCobradosEfectivo: 0,
                    totalFiadosCobradosQr: 0,
                    totalEntradasManuales: 0,
                    totalSalidasManuales: 0,
                    totalRetirosQr: 0,
                    totalSalidasTienda: 0,
                    totalSalidasPersonal: 0,
                    totalMercaderiaFutura: 0,
                    saldoNetoQr: 0,
                    montoEsperadoEfectivo: turno.montoInicial,
                  );

                  final tieneBuenMargen = r.balanceOperativoTienda >= r.totalSalidasPersonal;

                  return Column(
                    children: [
                      // ==========================================
                      // 1. LAS 2 BILLETERAS PRINCIPALES DEL NEGOCIO
                      // ==========================================
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BILLETERA 1: CAJÓN FÍSICO (EFECTIVO)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primary.withAlpha(220)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.point_of_sale, color: Colors.white70, size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'CAJÓN FÍSICO',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          mostrarEfectivo ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        onPressed: onToggleEfectivo,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mostrarEfectivo
                                        ? 'Bs. ${r.montoEsperadoEfectivo.toStringAsFixed(2)}'
                                        : 'Bs. ••••••',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Efectivo contante en gaveta',
                                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // BILLETERA 2: BANCO / QR (SALDO DISPONIBLE)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[800]!, Colors.blue[600]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'BANCO / QR',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mostrarEfectivo
                                        ? 'Bs. ${r.saldoNetoQr.toStringAsFixed(2)}'
                                        : 'Bs. ••••••',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cobrado QR menos cajero ATM',
                                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // BANNER CONSOLIDADO: TOTAL DINERO DISPONIBLE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.savings_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Dinero Total en Mano + Banco:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            Text(
                              mostrarEfectivo
                                  ? 'Bs. ${r.totalDineroDisponible.toStringAsFixed(2)}'
                                  : 'Bs. ••••••',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==========================================
                      // 2. TARJETA DE SALUD FINANCIERA DEL DÍA
                      // "¿Tu negocio realmente está ganando dinero?"
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: tieneBuenMargen
                                ? AppColors.success.withAlpha(80)
                                : Colors.amber.withAlpha(120),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: tieneBuenMargen
                                      ? AppColors.success.withAlpha(30)
                                      : Colors.amber.withAlpha(40),
                                  child: Icon(
                                    tieneBuenMargen ? Icons.trending_up : Icons.info_outline,
                                    size: 16,
                                    color: tieneBuenMargen ? AppColors.success : Colors.orange[800],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '¿Cómo va el negocio hoy?',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tieneBuenMargen
                                        ? AppColors.success.withAlpha(20)
                                        : Colors.amber.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tieneBuenMargen ? '🟢 Tienda Saludable' : '🟡 Cuidado con Retiros',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: tieneBuenMargen ? AppColors.success : Colors.orange[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 18),

                            // Fila 1: Total cobrado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Ingresos Cobrados:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text('Bs. ${r.totalIngresosDia.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Fila 2: Gastos de tienda
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gastos Tienda (Luz, bolsas, etc.):', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text('- Bs. ${r.totalSalidasTienda.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger)),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Fila 3: Apartado mercadería futura
                            if (r.totalMercaderiaFutura > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Apartado para Proveedores:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  Text('Bs. ${r.totalMercaderiaFutura.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Fila 4: Margen Operativo Limpio
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Margen Operativo de Tienda:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'Bs. ${r.balanceOperativoTienda.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: r.balanceOperativoTienda >= 0 ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Fila 5: Retiros Personales del Dueño
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Retiros Personales (Gastos de casa):', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text('Bs. ${r.totalSalidasPersonal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Consejo en vivo
                            Text(
                              tieneBuenMargen
                                  ? 'Tus ingresos cubren los gastos del negocio y tus retiros personales.'
                                  : 'Has retirado Bs. ${(r.totalSalidasPersonal - r.balanceOperativoTienda).toStringAsFixed(2)} más de lo generado hoy. Cuida no comerte el capital de mercadería.',
                              style: TextStyle(
                                fontSize: 11,
                                color: tieneBuenMargen ? Colors.grey[700] : Colors.orange[900],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tarjetas en Grid de Operaciones
                      Row(
                        children: [
                          Expanded(
                            child: _CardMetrica(
                              titulo: 'Ventas Efectivo',
                              valor: 'Bs. ${r.totalVentasEfectivo.toStringAsFixed(2)}',
                              icono: Icons.attach_money,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CardMetrica(
                              titulo: 'Ventas por QR',
                              subtitulo: '(En cuenta bancaria)',
                              valor: 'Bs. ${r.totalVentasQr.toStringAsFixed(2)}',
                              icono: Icons.qr_code_scanner,
                              color: Colors.blue[700]!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _CardMetrica(
                              titulo: 'Fiados Otorgados',
                              subtitulo: '(A crédito)',
                              valor: 'Bs. ${r.totalFiadosOtorgados.toStringAsFixed(2)}',
                              icono: Icons.pending_actions,
                              color: Colors.orange[800]!,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CardMetrica(
                              titulo: 'Fiados Cobrados',
                              subtitulo: '(Efectivo + QR)',
                              valor: 'Bs. ${(r.totalFiadosCobradosEfectivo + r.totalFiadosCobradosQr).toStringAsFixed(2)}',
                              icono: Icons.task_alt,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tarjeta Retiros y Salidas Totales
                      _CardMetrica(
                        titulo: 'Salidas y Retiros del Turno',
                        subtitulo: 'Cajón: Bs. ${r.totalSalidasManuales.toStringAsFixed(2)} | QR ATM: Bs. ${r.totalRetirosQr.toStringAsFixed(2)}',
                        valor: '- Bs. ${r.totalSalidasGlobales.toStringAsFixed(2)}',
                        icono: Icons.shopping_basket_outlined,
                        color: AppColors.danger,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Botón Acción Rápida: Entrada / Salida Manual (Caja o QR)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onRegistrarMovimiento,
                  icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                  label: const Text(
                    'REGISTRAR RETIRO O INGRESO (CAJA / QR)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Historial de Movimientos Manuales del Turno con tags de Origen y Categoría
              const Text(
                'Retiros y Movimientos de este turno',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              movimientosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (movs) {
                  if (movs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay gastos ni retiros registrados en este turno.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final m = movs[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: m.esSalida
                                  ? (m.esOrigenBancoQr ? Colors.blue.withAlpha(30) : AppColors.danger.withAlpha(25))
                                  : AppColors.success.withAlpha(25),
                              child: Icon(
                                m.esSalida ? Icons.arrow_upward : Icons.arrow_downward,
                                color: m.esSalida
                                    ? (m.esOrigenBancoQr ? Colors.blue[800] : AppColors.danger)
                                    : AppColors.success,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.motivo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: m.esOrigenBancoQr ? Colors.blue[50] : Colors.green[50],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          m.etiquetaOrigen,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: m.esOrigenBancoQr ? Colors.blue[800] : Colors.green[800],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          m.etiquetaCategoria,
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ),
                                      Text(
                                        '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${m.esSalida ? "-" : "+"}Bs. ${m.monto.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: m.esSalida ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Botón Inferior Masivo para Cerrar Caja
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: onIniciarArqueo,
            icon: const Icon(Icons.lock_clock, color: Colors.white, size: 28),
            label: const Text(
              'CERRAR CAJA Y REALIZAR ARQUEO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. VISTA DE ARQUEO: CONTEO CIEGO Y REVELACIÓN DE CUADRE
// ============================================================================
class _VistaArqueoConteo extends ConsumerWidget {
  final CajaTurnoModel turno;
  final bool revelarComparativa;
  final bool isProcessing;
  final TextEditingController observacionesController;
  final VoidCallback onVolver;
  final VoidCallback onRevelarComparativa;
  final Function(ResumenCajaModel resumen, double montoContado, Map<String, int> desglose) onConfirmarCierre;

  const _VistaArqueoConteo({
    required this.turno,
    required this.revelarComparativa,
    required this.isProcessing,
    required this.observacionesController,
    required this.onVolver,
    required this.onRevelarComparativa,
    required this.onConfirmarCierre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conteo = ref.watch(conteoCajaProvider);
    final resumenAsync = ref.watch(resumenCajaTurnoProvider);
    final granTotalContado = conteo.granTotal;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onVolver,
        ),
        title: const Text('Arqueo de Turno (Conteo Ciego)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reiniciar conteo',
            onPressed: () => ref.read(conteoCajaProvider.notifier).reiniciar(),
          ),
        ],
      ),
      body: SafeArea(
        child: resumenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (resumen) {
            final r = resumen ?? ResumenCajaModel(
              turnoId: turno.id,
              estado: 'ABIERTA',
              fechaApertura: turno.fechaApertura,
              montoInicial: turno.montoInicial,
              totalVentasEfectivo: 0,
              totalVentasQr: 0,
              totalFiadosOtorgados: 0,
              totalFiadosCobradosEfectivo: 0,
              totalFiadosCobradosQr: 0,
              totalEntradasManuales: 0,
              totalSalidasManuales: 0,
              totalRetirosQr: 0,
              totalSalidasTienda: 0,
              totalSalidasPersonal: 0,
              totalMercaderiaFutura: 0,
              saldoNetoQr: 0,
              montoEsperadoEfectivo: turno.montoInicial,
            );

            final double dif = ((granTotalContado - r.montoEsperadoEfectivo) * 100).round() / 100.0;
            final bool estaCuadrada = dif.abs() <= 1.0;
            final bool hayFaltante = dif < -1.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner informativo de Banco / QR
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo en Banco / QR (Verificar en tu App Bancaria):',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Bs. ${r.saldoNetoQr.toStringAsFixed(2)} neto disponible',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue[900]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Instrucción Conteo Ciego para el Cajón Físico
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.point_of_sale, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cuenta los billetes y monedas que tienes físicamente en la gaveta sin mirar el esperado:',
                            style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Denominaciones de Bolivia
                  ...Denominacion.values.map((denom) {
                    final cantidad = conteo.cantidades[denom] ?? 0;
                    final subtotal = denom.valor * cantidad;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: denom.esBillete ? Colors.green[100] : Colors.amber[100],
                              child: Icon(
                                denom.esBillete ? Icons.money : Icons.monetization_on,
                                color: denom.esBillete ? Colors.green[800] : Colors.amber[900],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    denom.etiqueta,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Subtotal: Bs. ${subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            // Botón Menos táctil
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.background,
                                minimumSize: const Size(42, 42),
                              ),
                              icon: const Icon(Icons.remove, size: 22),
                              onPressed: () => ref.read(conteoCajaProvider.notifier).decrementar(denom),
                            ),
                            // Cantidad Contada
                            Container(
                              constraints: const BoxConstraints(minWidth: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              alignment: Alignment.center,
                              child: Text(
                                '$cantidad',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Botón Más táctil
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary.withAlpha(25),
                                minimumSize: const Size(42, 42),
                              ),
                              icon: const Icon(Icons.add, color: AppColors.primary, size: 22),
                              onPressed: () => ref.read(conteoCajaProvider.notifier).incrementar(denom),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // Si se presiona "Comparar y Revelar", mostramos la tarjeta de auditoría
                  if (revelarComparativa) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: estaCuadrada
                            ? AppColors.success.withAlpha(20)
                            : (hayFaltante ? AppColors.danger.withAlpha(20) : AppColors.warning.withAlpha(20)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: estaCuadrada
                              ? AppColors.success
                              : (hayFaltante ? AppColors.danger : AppColors.warning),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                estaCuadrada
                                    ? Icons.check_circle
                                    : (hayFaltante ? Icons.cancel : Icons.warning_amber_rounded),
                                color: estaCuadrada
                                    ? AppColors.success
                                    : (hayFaltante ? AppColors.danger : AppColors.warning),
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  estaCuadrada
                                      ? '¡Caja Cuadrada Exactamente!'
                                      : (hayFaltante ? '¡Faltante de Dinero en Caja!' : '¡Sobrante de Dinero en Caja!'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: estaCuadrada
                                        ? AppColors.success
                                        : (hayFaltante ? AppColors.danger : AppColors.warning),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Efectivo en Cajón
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Físico Contado:', style: TextStyle(fontSize: 15)),
                              Text(
                                'Bs. ${granTotalContado.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Esperado por Sistema:', style: TextStyle(fontSize: 15)),
                              Text(
                                'Bs. ${r.montoEsperadoEfectivo.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('DIFERENCIA EFECTIVO:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(
                                '${dif >= 0 ? '+' : ''}Bs. ${dif.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: estaCuadrada
                                      ? AppColors.success
                                      : (hayFaltante ? AppColors.danger : AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),

                          // Billetera Banco / QR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saldo Neto en Banco / QR:', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                              Text(
                                'Bs. ${r.saldoNetoQr.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Gran Total Dinero Real al Cierre
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Real (Efectivo + Banco):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(
                                'Bs. ${(granTotalContado + r.saldoNetoQr).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de Observaciones
                    TextField(
                      controller: observacionesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observaciones / Justificación de cierre (opcional)',
                        hintText: estaCuadrada
                            ? 'Todo conforme en el turno'
                            : 'Ej. Error de cambio en venta de cerveza, etc.',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ),

      // Barra Inferior de Acción
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL FÍSICO CONTADO:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  'Bs. ${granTotalContado.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: !revelarComparativa
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onRevelarComparativa,
                      icon: const Icon(Icons.compare_arrows, color: Colors.white, size: 26),
                      label: const Text(
                        'COMPARAR Y REVELAR CUADRE',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isProcessing
                          ? null
                          : () {
                              final resumen = resumenAsync.value;
                              if (resumen != null) {
                                onConfirmarCierre(resumen, granTotalContado, conteo.toMapSerializable());
                              }
                            },
                      icon: isProcessing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle, color: Colors.white, size: 26),
                      label: Text(
                        isProcessing ? 'Procesando cierre...' : 'CONFIRMAR CIERRE DEFINITIVO',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMetrica extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _CardMetrica({
    required this.titulo,
    this.subtitulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(subtitulo!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}
