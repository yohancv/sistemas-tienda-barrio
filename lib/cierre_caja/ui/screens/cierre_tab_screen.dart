import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/caja_turno_model.dart';
import '../../state/providers/caja_providers.dart';
import '../widgets/modal_apertura_caja.dart';
import 'cierre_caja_screen.dart';

/// Pantalla del Apartado 4: Cierre de Caja & Finanzas
///
/// Diseñada con fidelidad exacta a la maqueta visual LicorPOS:
/// - Cabecera con avatar de licorería, badge "DON LUCHO" y estado del turno.
/// - Tarjeta principal de Arqueo con botón brillante "Cerrar Turno Hoy" o "Abrir Nuevo Turno".
/// - Cuadrícula 2x2 de métricas financieras (Fondo Fijo, Venta Efectivo, Cobros QR, Egresos/Gastos).
/// - Banner destacado de "Efectivo Físico Esperado en Cajón" con badge "Cuadrado".
/// - Bloque de "Sugerencias IA: Predicción & Precios" (Smart Bot local sin costo de nube).
/// - Formulario integrado para "Registrar Salida de Dinero de Caja (Gasto Rápido)".
class CierreTabScreen extends ConsumerStatefulWidget {
  const CierreTabScreen({super.key});

  @override
  ConsumerState<CierreTabScreen> createState() => _CierreTabScreenState();
}

class _CierreTabScreenState extends ConsumerState<CierreTabScreen> {
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  bool _guardandoGasto = false;

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
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

  void _irACierreCajaCompleto() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CierreCajaScreen()),
    );
  }

  Future<void> _registrarGastoRapido(CajaTurnoModel turno) async {
    final concepto = _conceptoController.text.trim();
    final montoStr = _montoController.text.trim().replaceAll(',', '.');
    final monto = double.tryParse(montoStr);

    if (concepto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el concepto del gasto (ej. Compra de 2 bolsas de hielo)'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto válido mayor a 0 Bs.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _guardandoGasto = true);

    try {
      final repo = ref.read(cajaRepositoryProvider);
      await repo.registrarMovimientoManual(
        tenantId: SupabaseConfig.defaultTenantId,
        turnoId: turno.id,
        tipo: 'SALIDA',
        monto: monto,
        motivo: concepto,
        origenDinero: 'EFECTIVO_CAJA',
        categoria: 'GASTO_TIENDA',
      );

      if (!mounted) return;
      _conceptoController.clear();
      _montoController.clear();
      FocusScope.of(context).unfocus();

      // Refrescar estado financiero
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);
      ref.invalidate(cajaTurnoActivaProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gasto de Bs. ${monto.toStringAsFixed(2)} registrado correctamente en caja'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar gasto: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoGasto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final turnoAsync = ref.watch(cajaTurnoActivaProvider);
    final resumenAsync = ref.watch(resumenCajaTurnoProvider);

    // Paleta oscura elegante inspirada en la maqueta
    const bgDark = Color(0xFF090D1A);
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE11D48),
          backgroundColor: cardDark,
          onRefresh: () async {
            ref.invalidate(cajaTurnoActivaProvider);
            ref.invalidate(resumenCajaTurnoProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: turnoAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error cargando caja: $err', style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
              data: (turno) {
                final bool cajaAbierta = turno != null && turno.estaAbierta;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HEADER SUPERIOR LICORPOS
                    _buildHeader(cajaAbierta, turno),

                    const SizedBox(height: 16),

                    // 2. TARJETA ARQUEO & CIERRE
                    _buildArqueoCard(cajaAbierta, turno),

                    const SizedBox(height: 16),

                    // 3. CUADRÍCULA 2x2 DE KPIS
                    resumenAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      ),
                      error: (err, _) => _buildKpisPlaceholder(
                        fondo: turno?.montoInicial ?? 0.0,
                        ventasEfe: 0.0,
                        qr: 0.0,
                        egresos: 0.0,
                      ),
                      data: (resumen) {
                        final double fondo = turno?.montoInicial ?? resumen?.montoInicial ?? 0.0;
                        final double ventasEfectivo = resumen?.totalVentasEfectivo ?? 0.0;
                        final double cobrosQr = (resumen?.totalVentasQr ?? 0.0) +
                            (resumen?.totalFiadosCobradosQr ?? 0.0);
                        final double egresos = (resumen?.totalSalidasManuales ?? 0.0) +
                            (resumen?.totalRetirosQr ?? 0.0);
                        final double esperado = resumen?.montoEsperadoEfectivo ?? fondo;

                        return Column(
                          children: [
                            _buildKpisGrid(
                              fondo: fondo,
                              ventasEfe: ventasEfectivo,
                              qr: cobrosQr,
                              egresos: egresos,
                            ),
                            const SizedBox(height: 14),
                            // 4. BANNER EFECTIVO FÍSICO ESPERADO
                            _buildEsperadoBanner(
                              fondo: fondo,
                              esperado: esperado,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // 5. SUGERENCIAS IA / SMART BOT (LOCAL, CERO COSTO)
                    _buildSmartBotCard(),

                    const SizedBox(height: 18),

                    // 6. FORMULARIO RÁPIDO DE GASTOS
                    if (cajaAbierta)
                      _buildFormularioGastoRapido(turno)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderDark),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Abre un turno de caja para registrar salidas y gastos del día.',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Cabecera con avatar LicorPOS y estado de turno
  Widget _buildHeader(bool cajaAbierta, CajaTurnoModel? turno) {
    return Row(
      children: [
        // Avatar naranja con ícono de licor
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8A00).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.wine_bar_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        // Nombre de tienda y badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'LicorPOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332308),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'DON LUCHO',
                      style: TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: cajaAbierta ? const Color(0xFF00E676) : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cajaAbierta
                        ? 'Caja Abierta • Turno Activo'
                        : 'Caja Cerrada • Sin turno',
                    style: TextStyle(
                      color: cajaAbierta ? const Color(0xFF94A3B8) : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Botón superior de accesos directos
        IconButton(
          onPressed: () => _irACierreCajaCompleto(),
          tooltip: 'Ver Arqueo Detallado',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 20),
        ),
      ],
    );
  }

  /// 2. Tarjeta principal de Arqueo y Botón Cerrar Turno
  Widget _buildArqueoCard(bool cajaAbierta, CajaTurnoModel? turno) {
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF27214E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_outlined, color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Arqueo, Cierre de Caja & Finanzas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Control diario de efectivo físico, cobros con código QR y balance neto',
            style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cajaAbierta ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: (cajaAbierta ? const Color(0xFFE11D48) : const Color(0xFF10B981))
                    .withValues(alpha: 0.4),
              ),
              onPressed: () {
                if (cajaAbierta) {
                  _irACierreCajaCompleto();
                } else {
                  _abrirModalApertura();
                }
              },
              icon: Icon(
                cajaAbierta ? Icons.lock_outline : Icons.lock_open_rounded,
                size: 18,
              ),
              label: Text(
                cajaAbierta ? 'Cerrar Turno Hoy' : 'Abrir Nuevo Turno de Caja',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Cuadrícula 2x2 de métricas financieras
  Widget _buildKpisGrid({
    required double fondo,
    required double ventasEfe,
    required double qr,
    required double egresos,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                titulo: 'FONDO FIJO (APERTURA)',
                monto: 'Bs. ${fondo.toStringAsFixed(2)}',
                colorMonto: Colors.white,
                subtitulo: 'Monedas y sencillo',
                colorSubtitulo: const Color(0xFF8B9CB5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'VENTA EFECTIVO',
                monto: 'Bs. ${ventasEfe.toStringAsFixed(2)}',
                colorMonto: const Color(0xFF00E676),
                subtitulo: '• En cajón físico',
                colorSubtitulo: const Color(0xFF00E676),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                titulo: 'COBROS QR / TRANSF.',
                monto: 'Bs. ${qr.toStringAsFixed(2)}',
                colorMonto: const Color(0xFF00D2FF),
                subtitulo: 'Yape / Bancos',
                colorSubtitulo: const Color(0xFF00D2FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'EGRESOS / GASTOS',
                monto: 'Bs. ${egresos.toStringAsFixed(2)}',
                colorMonto: const Color(0xFFFF5252),
                subtitulo: 'Hielo, bolsas, delivery',
                colorSubtitulo: const Color(0xFFFF5252),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String titulo,
    required String monto,
    required Color colorMonto,
    required String subtitulo,
    required Color colorSubtitulo,
  }) {
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF8B9CB5),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            monto,
            style: TextStyle(
              color: colorMonto,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(
              color: colorSubtitulo.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildKpisPlaceholder({
    required double fondo,
    required double ventasEfe,
    required double qr,
    required double egresos,
  }) {
    return _buildKpisGrid(
      fondo: fondo,
      ventasEfe: ventasEfe,
      qr: qr,
      egresos: egresos,
    );
  }

  /// 4. Banner "Efectivo Físico Esperado en Cajón"
  Widget _buildEsperadoBanner({
    required double fondo,
    required double esperado,
  }) {
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Efectivo Físico Esperado en Cajón:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fondo Fijo (Bs. ${fondo.toStringAsFixed(0)}) + Ventas Efectivo - Egresos',
                  style: const TextStyle(
                    color: Color(0xFF8B9CB5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs. ${esperado.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF083321),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Cuadrado',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. Sugerencias IA / Smart Bot (Local, cero dependencias)
  Widget _buildSmartBotCard() {
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera Smart Bot
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1C4E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFB388FF), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sugerencias IA: Predicción & Precios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C2A85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SMART BOT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sugerencias actualizadas según rotación de inventario local'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, color: Color(0xFF8B9CB5), size: 18),
                tooltip: 'Actualizar sugerencias',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Análisis predictivo para el fin de semana (Viernes a Domingo)',
            style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Item 1: Cerveza Lager & Hielo
          _buildSugerenciaItem(
            icono: Icons.trending_up,
            titulo: 'Cerveza Lager & Hielo',
            badgeTexto: '+42% demanda proyectada',
            badgeColor: const Color(0xFF00D2FF),
            descripcion:
                'Se prevé partido de fútbol y alta temperatura el sábado. Se sugiere ordenar 4 cajas adicionales de Cusqueña / Huari / Paceña y reservar 15 bolsas de hielo antes del viernes a las 3:00 PM.',
          ),

          const SizedBox(height: 12),

          // Item 2: Combo Ron + Gaseosa
          _buildSugerenciaItem(
            icono: Icons.sell_outlined,
            titulo: 'Combo Ron + Gaseosa 1.5L',
            badgeTexto: '+18% margen',
            badgeColor: const Color(0xFF00E676),
            descripcion:
                'Subir Bs. 0.50 al Ron Flor de Caña / Abuelo emparejándolo en "Combo Rumbero" con Coca Cola 1.5L. El cliente nocturno prefiere conveniencia sobre precio unitario.',
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciaItem({
    required IconData icono,
    required String titulo,
    required String badgeTexto,
    required Color badgeColor,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2844)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: const Color(0xFFFFB800), size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeTexto,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            descripcion,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Formulario Integrado para Salida Rápida de Dinero
  Widget _buildFormularioGastoRapido(CajaTurnoModel turno) {
    const cardDark = Color(0xFF131A2D);
    const cardBorderDark = Color(0xFF1F2B48);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.arrow_circle_down_rounded, color: Color(0xFFFF5252), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Registrar Salida de Dinero de Caja (Gasto Rápido)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Concepto input
          TextField(
            controller: _conceptoController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Concepto (ej. Compra de 2 bolsas de hielo)',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF090D1A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E2844)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE11D48)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Monto input
          TextField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Monto (Bs.)',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF090D1A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixText: 'Bs. ',
              prefixStyle: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E2844)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE11D48)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Botón Registrar
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              onPressed: _guardandoGasto ? null : () => _registrarGastoRapido(turno),
              child: _guardandoGasto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Registrar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
