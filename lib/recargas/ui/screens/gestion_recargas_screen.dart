import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../data/models/operadora_model.dart';
import '../../data/models/recarga_model.dart';
import '../../state/providers/recargas_providers.dart';

class GestionRecargasScreen extends ConsumerStatefulWidget {
  const GestionRecargasScreen({super.key});

  @override
  ConsumerState<GestionRecargasScreen> createState() => _GestionRecargasScreenState();
}

class _GestionRecargasScreenState extends ConsumerState<GestionRecargasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filtroGuiaOperadora = 'TODAS';
  final TextEditingController _busquedaGuiaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaGuiaController.dispose();
    super.dispose();
  }

  Color _obtenerColorOperadora(String id) {
    switch (id.toUpperCase()) {
      case 'ENTEL':
        return const Color(0xFF005CA9);
      case 'TIGO':
        return const Color(0xFF00377B);
      case 'VIVA':
        return const Color(0xFF7DB637);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  void _abrirModalCargarSaldo(OperadoraModel op) {
    final saldoCargadoCtrl = TextEditingController(text: '100');
    final dineroPagadoCtrl = TextEditingController(text: '100');
    String origenPago = 'EFECTIVO_CAJA';
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
          final colorOp = _obtenerColorOperadora(op.id);

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + (isKeyboard ? MediaQuery.of(context).viewInsets.bottom : 12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorOp.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.add_shopping_cart_rounded, color: colorOp, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cargar Saldo Mayorista a ${op.nombre}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('SALDO QUE RECIBES EN TU CHIP (BS.)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: saldoCargadoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: 'Bs. ',
                      prefixStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('DINERO QUE PAGASTE (BS.)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dineroPagadoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: 'Bs. ',
                      prefixStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('¿DE DÓNDE SALIÓ EL DINERO?',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => origenPago = 'EFECTIVO_CAJA'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: origenPago == 'EFECTIVO_CAJA' ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: origenPago == 'EFECTIVO_CAJA' ? const Color(0xFF10B981) : Colors.white12,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                                SizedBox(height: 4),
                                Text('Efectivo de Caja',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Descuenta del cajón',
                                    style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => origenPago = 'BANCO_QR_EXTERNO'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: origenPago == 'BANCO_QR_EXTERNO' ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: origenPago == 'BANCO_QR_EXTERNO' ? const Color(0xFF60A5FA) : Colors.white12,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                                SizedBox(height: 4),
                                Text('Banco / Externo',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('No afecta la caja física',
                                    style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorOp,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: guardando
                          ? null
                          : () async {
                              final saldo = double.tryParse(saldoCargadoCtrl.text.replaceAll(',', '.')) ?? 0.0;
                              final dinero = double.tryParse(dineroPagadoCtrl.text.replaceAll(',', '.')) ?? 0.0;
                              if (saldo <= 0) return;

                              setModalState(() => guardando = true);
                              try {
                                final repo = ref.read(recargasRepositoryProvider);
                                final turno = ref.read(cajaTurnoActivaProvider).valueOrNull;

                                await repo.recargarBolsaSaldo(
                                  tenantId: SupabaseConfig.defaultTenantId,
                                  operadora: op,
                                  saldoCargado: saldo,
                                  dineroPagado: dinero,
                                  origenPago: origenPago,
                                  cajaTurnoId: turno?.id,
                                );

                                ref.invalidate(operadorasListProvider);
                                ref.invalidate(resumenCajaTurnoProvider);
                                ref.invalidate(cajaTurnoActivaProvider);

                                if (context.mounted) Navigator.pop(context);
                              } finally {
                                if (context.mounted) setModalState(() => guardando = false);
                              }
                            },
                      child: guardando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('REGISTRAR CARGA DE SALDO',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editarComision(OperadoraModel op) {
    final comisionCtrl = TextEditingController(text: op.comisionPorcentaje.toStringAsFixed(0));
    final alertaCtrl = TextEditingController(text: op.saldoAlertaMinimo.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Ajustar ${op.nombre}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Porcentaje de comisión / ganancia (%):', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 6),
            TextField(
              controller: comisionCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Avisar si el saldo baja de (Bs.):', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 6),
            TextField(
              controller: alertaCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'Bs. ',
                prefixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final comision = double.tryParse(comisionCtrl.text) ?? op.comisionPorcentaje;
              final alerta = double.tryParse(alertaCtrl.text) ?? op.saldoAlertaMinimo;

              final nuevo = op.copyWith(comisionPorcentaje: comision, saldoAlertaMinimo: alerta);
              await ref.read(recargasRepositoryProvider).actualizarOperadora(nuevo);
              ref.invalidate(operadorasListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recargas & Servicios Telefónicos',
              style: TextStyle(color: textPrimary, fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
            Text(
              'Entel • Tigo • Viva (Bolivia)',
              style: TextStyle(color: textSecondary, fontSize: 11.5),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49.0),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.retailBlue,
                indicatorWeight: 3,
                labelColor: AppColors.retailBlue,
                unselectedLabelColor: textSecondary,
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'Bolsas de Saldo'),
                  Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Ventas de Hoy'),
                  Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Guía Paquetes'),
                ],
              ),
              Container(color: cardBorder, height: 1.0),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabBolsas(),
          _buildTabHistorial(),
          _buildTabGuiaPaquetes(),
        ],
      ),
    );
  }

  /// Pestaña 1: Bolsas de Saldo & Configuración
  Widget _buildTabBolsas() {
    final operadorasAsync = ref.watch(operadorasListProvider);

    return operadorasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF005CA9))),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (operadoras) {
        final double saldoTotal = operadoras.where((op) => op.activa).fold<double>(0.0, (acc, op) => acc + op.saldoActual);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resumen superior
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sim_card_outlined, color: Color(0xFF60A5FA), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SALDO TOTAL DISPONIBLE EN CHIPS',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Bs. ${saldoTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'OPERADORAS HABILITADAS',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
            const SizedBox(height: 10),

            // Tarjetas de Operadoras
            for (final op in operadoras) ...[
              _buildOperadoraCard(op),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOperadoraCard(OperadoraModel op) {
    final colorOp = _obtenerColorOperadora(op.id);
    final esOscuro = ref.watch(esModoOscuroProvider);
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: op.saldoBajo ? Colors.amber : cardBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: colorOp, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                op.nombre,
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Switch activa
              Text(
                op.activa ? 'Habilitada' : 'Desactivada',
                style: TextStyle(color: op.activa ? textSecondary : AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Switch(
                value: op.activa,
                activeThumbColor: colorOp,
                activeTrackColor: colorOp.withValues(alpha: 0.4),
                onChanged: (val) async {
                  await ref.read(recargasRepositoryProvider).actualizarOperadora(op.copyWith(activa: val));
                  ref.invalidate(operadorasListProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Saldo actual: ', style: TextStyle(color: textSecondary, fontSize: 13)),
              Text(
                'Bs. ${op.saldoActual.toStringAsFixed(2)}',
                style: TextStyle(
                  color: op.saldoBajo ? Colors.amber : AppColors.retailGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _editarComision(op),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: esOscuro ? Colors.white12 : const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Comisión: ',
                        style: TextStyle(color: AppColors.retailBlue, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.edit, size: 12, color: AppColors.retailBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (op.saldoBajo) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Saldo por debajo del límite mínimo (Bs. ${op.saldoAlertaMinimo.toStringAsFixed(0)})',
                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: colorOp.withValues(alpha: 0.7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _abrirModalCargarSaldo(op),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('CARGAR SALDO A MI CHIP (COMPRA MAYORISTA)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// Pestaña 2: Historial del Día & Ganancias
  Widget _buildTabHistorial() {
    final resumenAsync = ref.watch(resumenRecargasTurnoProvider);
    final ventasAsync = ref.watch(recargasTurnoProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPIs de ventas del turno
        resumenAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, stack) => const SizedBox.shrink(),
          data: (resumen) {
            final double total = (resumen['total_monto'] as num?)?.toDouble() ?? 0.0;
            final double ganancia = (resumen['total_ganancia'] as num?)?.toDouble() ?? 0.0;
            final int cantidad = (resumen['cantidad'] as num?)?.toInt() ?? 0;
            final double efe = (resumen['total_efectivo'] as num?)?.toDouble() ?? 0.0;
            final double qr = (resumen['total_qr'] as num?)?.toDouble() ?? 0.0;

            return Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RECARGADO HOY',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Bs. ${total.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('$cantidad ${cantidad == 1 ? "recarga" : "recargas"} ($efe efe / $qr qr)',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F291E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GANANCIA NETA',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Bs. ${ganancia.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text('Margen neto puro',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'HISTORIAL DEL TURNO',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),

        // Lista de recargas
        ventasAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
          data: (ventas) {
            if (ventas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16)),
                child: const Center(
                  child: Text(
                    'No se han registrado recargas en este turno todavía.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final v in ventas) ...[
                  _buildVentaItem(v),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildVentaItem(RecargaModel v) {
    final colorOp = _obtenerColorOperadora(v.operadoraId);
    final horaStr = '${v.createdAt.hour.toString().padLeft(2, '0')}:${v.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colorOp.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.phone_android_rounded, color: colorOp, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      v.operadoraNombre,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: v.metodoPago == MetodoPagoRecarga.efectivo ? const Color(0xFF065F46) : const Color(0xFF0369A1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        v.metodoPago == MetodoPagoRecarga.efectivo ? 'Efectivo' : 'QR',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${v.tipo == TipoRecarga.credito ? "Crédito" : "Internet"} ${v.numeroTelefono != null ? "• Cel: ${v.numeroTelefono}" : ""} • $horaStr',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs. ${v.monto.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                '+Bs. ${v.gananciaNeta.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
            tooltip: 'Anular recarga',
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('¿Anular esta recarga?', style: TextStyle(color: Colors.white)),
                  content: Text(
                    'Se restaurarán Bs. ${v.monto.toStringAsFixed(2)} a la bolsa de ${v.operadoraNombre} y se ajustará la caja.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sí, anular', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirmar == true) {
                await ref.read(recargasRepositoryProvider).anularVentaRecarga(v.id, SupabaseConfig.defaultTenantId);
                ref.invalidate(recargasTurnoProvider);
                ref.invalidate(resumenRecargasTurnoProvider);
                ref.invalidate(operadorasListProvider);
                ref.invalidate(resumenCajaTurnoProvider);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Pestaña 3: Guía de Paquetes de Internet (Bolivia)
  Widget _buildTabGuiaPaquetes() {
    final List<Map<String, String>> paquetes = [
      // ENTEL
      {
        'operadora': 'ENTEL',
        'nombre': 'Ilimitado 2 Horas',
        'precio': 'Bs. 5',
        'duracion': '2 Horas',
        'activacion': 'Marcar *10# o App Entel',
        'descripcion': 'Internet sin límite de velocidad por 120 minutos.',
      },
      {
        'operadora': 'ENTEL',
        'nombre': 'Ilimitado 1 Hora',
        'precio': 'Bs. 3',
        'duracion': '1 Hora',
        'activacion': 'Marcar *10# o App Entel',
        'descripcion': 'Navegación libre por 60 minutos.',
      },
      {
        'operadora': 'ENTEL',
        'nombre': 'Paquetico Noche Ilimitado',
        'precio': 'Bs. 5',
        'duracion': '00:00 a 06:00 AM',
        'activacion': 'Marcar *10#',
        'descripcion': 'Descargas y navegación sin límite durante la madrugada.',
      },
      {
        'operadora': 'ENTEL',
        'nombre': 'Bolsa Diaria 500 MB',
        'precio': 'Bs. 5',
        'duracion': '24 Horas',
        'activacion': 'Marcar *10#',
        'descripcion': '500 megabytes vigentes hasta las 23:59.',
      },
      {
        'operadora': 'ENTEL',
        'nombre': 'Bolsa Semanal 1200 MB',
        'precio': 'Bs. 10',
        'duracion': '7 Días',
        'activacion': 'Marcar *10#',
        'descripcion': '1.2 GB para uso durante toda la semana.',
      },
      // TIGO
      {
        'operadora': 'TIGO',
        'nombre': 'Paquetigo Ilimitado 2 Horas',
        'precio': 'Bs. 5',
        'duracion': '2 Horas',
        'activacion': 'Marcar *123# o Tigo Shop',
        'descripcion': 'Internet ilimitado para videos y redes por 2 horas.',
      },
      {
        'operadora': 'TIGO',
        'nombre': 'Paquetigo Ilimitado 1 Hora',
        'precio': 'Bs. 3',
        'duracion': '1 Hora',
        'activacion': 'Marcar *123# o Tigo Shop',
        'descripcion': 'Navegación continua por 60 minutos.',
      },
      {
        'operadora': 'TIGO',
        'nombre': 'Megas + WhatsApp Ilimitado',
        'precio': 'Bs. 5',
        'duracion': '24 Horas',
        'activacion': 'Marcar *123#',
        'descripcion': '500 MB libres + WhatsApp libre todo el día.',
      },
      {
        'operadora': 'TIGO',
        'nombre': 'Paquetigo 48 Horas (2 Días)',
        'precio': 'Bs. 10',
        'duracion': '2 Días',
        'activacion': 'Marcar *123#',
        'descripcion': '1200 MB + llamadas ilimitadas Tigo a Tigo.',
      },
      {
        'operadora': 'TIGO',
        'nombre': 'Paquetigo Nocturno Ilimitado',
        'precio': 'Bs. 5',
        'duracion': '00:00 a 06:00 AM',
        'activacion': 'Marcar *123#',
        'descripcion': 'Sin consumo de megas en horario nocturno.',
      },
      // VIVA
      {
        'operadora': 'VIVA',
        'nombre': 'Bolsa 2 Horas Ilimitada',
        'precio': 'Bs. 5',
        'duracion': '2 Horas',
        'activacion': 'Marcar *511# o App Viva',
        'descripcion': 'Internet libre por 120 minutos.',
      },
      {
        'operadora': 'VIVA',
        'nombre': 'Bolsa 1 Hora Ilimitada',
        'precio': 'Bs. 3',
        'duracion': '1 Hora',
        'activacion': 'Marcar *511#',
        'descripcion': 'Internet libre por 60 minutos.',
      },
      {
        'operadora': 'VIVA',
        'nombre': 'Bolsa Diaria 600 MB',
        'precio': 'Bs. 5',
        'duracion': '24 Horas',
        'activacion': 'Marcar *511#',
        'descripcion': '600 megabytes para todo el día.',
      },
      {
        'operadora': 'VIVA',
        'nombre': 'Bolsa 3 Días (1.5 GB)',
        'precio': 'Bs. 10',
        'duracion': '3 Días',
        'activacion': 'Marcar *511#',
        'descripcion': '1500 MB con vigencia de 72 horas.',
      },
    ];

    final query = _busquedaGuiaController.text.trim().toLowerCase();
    final filtrados = paquetes.where((p) {
      final coincideOp = _filtroGuiaOperadora == 'TODAS' || p['operadora'] == _filtroGuiaOperadora;
      final coincideTxt = query.isEmpty ||
          p['nombre']!.toLowerCase().contains(query) ||
          p['precio']!.toLowerCase().contains(query) ||
          p['descripcion']!.toLowerCase().contains(query);
      return coincideOp && coincideTxt;
    }).toList();

    return Column(
      children: [
        // Buscador y filtros de operadora
        Container(
          color: AppColors.darkSurface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _busquedaGuiaController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar paquete (ej. 2 horas, ilimitado, 5 bs)...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 20),
                  suffixIcon: _busquedaGuiaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                          onPressed: () {
                            _busquedaGuiaController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.darkBackground,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFiltroChip('TODAS', 'Todas'),
                  const SizedBox(width: 6),
                  _buildFiltroChip('ENTEL', 'Entel', color: const Color(0xFF005CA9)),
                  const SizedBox(width: 6),
                  _buildFiltroChip('TIGO', 'Tigo', color: const Color(0xFF00377B)),
                  const SizedBox(width: 6),
                  _buildFiltroChip('VIVA', 'Viva', color: const Color(0xFF7DB637)),
                ],
              ),
            ],
          ),
        ),

        // Lista de paquetes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtrados.length,
            itemBuilder: (ctx, index) {
              final p = filtrados[index];
              final color = _obtenerColorOperadora(p['operadora']!);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        p['operadora']!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['nombre']!,
                            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            p['descripcion']!,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFF64748B), size: 14),
                              const SizedBox(width: 4),
                              Text(p['duracion']!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(width: 12),
                              const Icon(Icons.dialpad, color: Color(0xFF64748B), size: 14),
                              const SizedBox(width: 4),
                              Text(p['activacion']!, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F291E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        p['precio']!,
                        style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String id, String label, {Color? color}) {
    final isSel = _filtroGuiaOperadora == id;
    final activeColor = color ?? const Color(0xFF2563EB);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filtroGuiaOperadora = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? activeColor : AppColors.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSel ? Colors.white : Colors.white12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
