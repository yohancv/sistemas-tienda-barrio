import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../cuentas_por_cobrar/ui/widgets/modal_cobro_whatsapp.dart';
import '../../../inteligencia_negocio/data/models/insight_model.dart';
import '../../../inteligencia_negocio/state/providers/bi_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/ui/screens/formulario_producto_screen.dart';
import '../../data/models/caja_turno_model.dart';
import '../../data/models/resumen_caja_model.dart';
import '../../state/providers/caja_providers.dart';
import '../widgets/modal_apertura_caja.dart';
import '../widgets/modal_movimiento_manual.dart';
import '../widgets/modal_corte_diario.dart';
import 'cierre_caja_screen.dart';
import '../../../recargas/state/providers/recargas_providers.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/theme/theme_provider.dart';

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
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalAperturaCaja(),
    );
  }

  void _abrirModalCorteDiario(CajaTurnoModel turno, ResumenCajaModel resumen) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalCorteDiario(turno: turno, resumen: resumen),
    );
  }

  void _abrirModalRetiroPersonal(String turnoId) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalMovimientoManual(turnoId: turnoId),
    );
  }

  void _irACierreCajaCompleto() {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CierreCajaScreen()),
    );
  }

  Future<void> _ejecutarAccionInsight(InsightModel insight) async {
    switch (insight.tipoAccion) {
      case TipoAccionInsight.abrirCobroVecino:
        if (insight.entidadId != null) {
          try {
            final repo = ref.read(clientesRepositoryProvider);
            final cliente = await repo.obtenerClientePorId(insight.entidadId!);
            if (cliente != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ModalCobroWhatsApp(cliente: cliente),
              );
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se encontró información del cliente.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al abrir cobro: $e'),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
        }
        break;

      case TipoAccionInsight.abrirPedidoProveedor:
        final provNombre = (insight.metadata['proveedor_nombre'] as String?) ?? 'Proveedor';
        final tel = (insight.metadata['proveedor_telefono'] as String?) ?? '';
        final cleanPhone = tel.replaceAll(RegExp(r'[^0-9]'), '');
        String phoneParam = cleanPhone;
        if (cleanPhone.length == 8) {
          phoneParam = '591$cleanPhone';
        }

        final items = (insight.metadata['items'] as List<dynamic>?) ?? [];
        final buffer = StringBuffer();
        buffer.writeln('📋 *PEDIDO DE REPOSICIÓN - TIENDA DE BARRIO*');
        buffer.writeln('Hola *$provNombre*, le envío el pedido de reposición para mañana:');
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          final nom = it['nombre'] ?? '';
          final actual = (it['stock_actual'] as num?)?.toDouble() ?? 0.0;
          final min = (it['stock_minimo'] as num?)?.toDouble() ?? 0.0;
          final cantSugerida = (min * 2 - actual).clamp(1.0, 999.0).toInt();
          buffer.writeln('${i + 1}. *$nom* - Pedir: $cantSugerida uds.');
        }
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        buffer.writeln('Por favor confirmar recepción. ¡Muchas gracias!');

        final msg = buffer.toString();
        final urlStr = phoneParam.isNotEmpty
            ? 'https://wa.me/$phoneParam?text=${Uri.encodeComponent(msg)}'
            : 'https://wa.me/?text=${Uri.encodeComponent(msg)}';
        final uri = Uri.parse(urlStr);
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            final fallback = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
            if (await canLaunchUrl(fallback)) {
              await launchUrl(fallback, mode: LaunchMode.externalApplication);
            }
          }
        } catch (_) {}
        break;

      case TipoAccionInsight.silenciarEstacional:
        if (insight.entidadId != null) {
          try {
            final biRepo = ref.read(biAnalyticsRepositoryProvider);
            await biRepo.silenciarProductoEstacional(insight.entidadId!);
            ref.invalidate(sugerenciasInteligentesProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❄️ Producto silenciado como estacional. No volverá a alertar en temporada baja.'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al silenciar producto: $e'),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
        }
        break;

      case TipoAccionInsight.abrirEdicionProducto:
        if (insight.entidadId != null) {
          try {
            final invRepo = ref.read(inventarioRepositoryProvider);
            final prod = await invRepo.obtenerProductoPorId(insight.entidadId!);
            if (prod != null && mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FormularioProductoScreen(productoParaEditar: prod),
                ),
              );
              ref.invalidate(sugerenciasInteligentesProvider);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al abrir edición: $e'),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
        }
        break;

      case TipoAccionInsight.soloLectura:
        _irACierreCajaCompleto();
        break;
    }
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
      AppHaptics.medium();
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
    final esOscuro = ref.watch(esModoOscuroProvider);

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE11D48),
          backgroundColor: cardBg,
          onRefresh: () async {
            ref.invalidate(cajaTurnoActivaProvider);
            ref.invalidate(resumenCajaTurnoProvider);
            ref.invalidate(sugerenciasInteligentesProvider);
            ref.invalidate(resumenRecargasTurnoProvider);
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
                    _buildHeader(cajaAbierta, turno, esOscuro),

                    const SizedBox(height: 16),

                    // 2. TARJETA ARQUEO & CIERRE
                    _buildArqueoCard(cajaAbierta, turno, resumenAsync.value, esOscuro),

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
                        esOscuro: esOscuro,
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
                              esOscuro: esOscuro,
                            ),
                            const SizedBox(height: 14),
                            // 4. BANNER EFECTIVO FÍSICO ESPERADO
                            _buildEsperadoBanner(
                              fondo: fondo,
                              esperado: esperado,
                              esOscuro: esOscuro,
                            ),
                            // 4.1 Resumen de Recargas Telefónicas si hubo en el turno
                            _buildResumenRecargasCaja(esOscuro),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // 5. SUGERENCIAS IA / SMART BOT (LOCAL, CERO COSTO)
                    _buildSmartBotCard(esOscuro),

                    const SizedBox(height: 18),

                    // 6. FORMULARIO RÁPIDO DE GASTOS
                    if (cajaAbierta)
                      _buildFormularioGastoRapido(turno, esOscuro)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Abre un turno de caja para registrar salidas y gastos del día.',
                                style: TextStyle(color: textMuted, fontSize: 13),
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
  Widget _buildHeader(bool cajaAbierta, CajaTurnoModel? turno, bool esOscuro) {
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;

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
                blurRadius: 4,
                offset: const Offset(0, 2),
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
                  Flexible(
                    child: Text(
                      'Licorería & Tienda de Barrio',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: esOscuro ? const Color(0xFF332308) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: esOscuro
                            ? const Color(0xFFFFB800).withValues(alpha: 0.5)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      'DON LUCHO',
                      style: TextStyle(
                        color: esOscuro ? const Color(0xFFFFB800) : const Color(0xFFB45309),
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
                      color: cajaAbierta ? (esOscuro ? const Color(0xFF00E676) : AppColors.retailGreen) : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cajaAbierta
                        ? 'Caja Abierta • Turno Activo'
                        : 'Caja Cerrada • Sin turno',
                    style: TextStyle(
                      color: cajaAbierta ? (esOscuro ? const Color(0xFF94A3B8) : AppColors.retailGreen) : Colors.redAccent,
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
            backgroundColor: esOscuro ? const Color(0xFF1E293B) : AppColors.surfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: esOscuro ? Colors.transparent : AppColors.border),
            ),
          ),
          icon: Icon(
            Icons.auto_awesome,
            color: esOscuro ? const Color(0xFFFFD54F) : const Color(0xFFD97706),
            size: 20,
          ),
        ),
      ],
    );
  }

  /// 2. Tarjeta principal de Caja del Día & Acciones del Dueño
  Widget _buildArqueoCard(bool cajaAbierta, CajaTurnoModel? turno, ResumenCajaModel? resumen, bool esOscuro) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
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
                  color: esOscuro ? const Color(0xFF27214E) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: esOscuro ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja Continua & Finanzas',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Control diario de efectivo físico y cobros QR para el dueño',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Botón Principal: Corte del Día
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (turno != null && resumen != null) {
                        _abrirModalCorteDiario(turno, resumen);
                      } else if (!cajaAbierta) {
                        _abrirModalApertura();
                      } else {
                        _irACierreCajaCompleto();
                      }
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                    ),
                    label: const Text(
                      'Hacer Corte del Día',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Secundario: Retiro Dueño
              if (cajaAbierta && turno != null)
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: esOscuro ? Colors.white : AppColors.textPrimary,
                        side: BorderSide(color: cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _abrirModalRetiroPersonal(turno.id),
                      icon: const Icon(Icons.person_outline, size: 17, color: Colors.orange),
                      label: const Text(
                        'Retiro Dueño',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
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
    required bool esOscuro,
  }) {
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final greenColor = esOscuro ? AppColors.darkSuccessBright : AppColors.retailGreen;
    final skyColor = esOscuro ? AppColors.darkAccent : const Color(0xFF0284C7);
    final redColor = const Color(0xFFE11D48);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                titulo: 'FONDO FIJO (APERTURA)',
                monto: 'Bs. ${fondo.toStringAsFixed(2)}',
                colorMonto: textPrimary,
                subtitulo: 'Monedas y sencillo',
                colorSubtitulo: esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted,
                esOscuro: esOscuro,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'VENTA EFECTIVO',
                monto: 'Bs. ${ventasEfe.toStringAsFixed(2)}',
                colorMonto: greenColor,
                subtitulo: '• En cajón físico',
                colorSubtitulo: greenColor,
                esOscuro: esOscuro,
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
                colorMonto: skyColor,
                subtitulo: 'Yape / Bancos',
                colorSubtitulo: skyColor,
                esOscuro: esOscuro,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'EGRESOS / GASTOS',
                monto: 'Bs. ${egresos.toStringAsFixed(2)}',
                colorMonto: redColor,
                subtitulo: 'Hielo, bolsas, delivery',
                colorSubtitulo: redColor,
                esOscuro: esOscuro,
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
    required bool esOscuro,
  }) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: textMuted,
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
              color: colorSubtitulo.withValues(alpha: 0.9),
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
    required bool esOscuro,
  }) {
    return _buildKpisGrid(
      fondo: fondo,
      ventasEfe: ventasEfe,
      qr: qr,
      egresos: egresos,
      esOscuro: esOscuro,
    );
  }

  /// 4. Banner "Efectivo Físico Esperado en Cajón"
  Widget _buildEsperadoBanner({
    required double fondo,
    required double esperado,
    required bool esOscuro,
  }) {
    final cardBg = esOscuro ? AppColors.darkSurface : const Color(0xFFF0FDF4);
    final cardBorder = esOscuro ? AppColors.darkBorder : const Color(0xFFBBF7D0);
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : const Color(0xFF14532D);
    final textMuted = esOscuro ? AppColors.darkTextSecondary : const Color(0xFF15803D);
    final greenAmount = esOscuro ? AppColors.darkSuccessBright : AppColors.retailGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Efectivo Físico Esperado en Cajón:',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fondo Fijo (Bs. ${fondo.toStringAsFixed(0)}) + Ventas Efectivo - Egresos',
                  style: TextStyle(
                    color: textMuted,
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
                style: TextStyle(
                  color: greenAmount,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: esOscuro ? const Color(0xFF0C243B) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: esOscuro
                        ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  'Calculado en sistema',
                  style: TextStyle(
                    color: esOscuro ? const Color(0xFF38BDF8) : const Color(0xFF16A34A),
                    fontSize: 10.5,
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

  /// 4.1 Resumen de Recargas Telefónicas en el Turno
  Widget _buildResumenRecargasCaja(bool esOscuro) {
    final recargasAsync = ref.watch(resumenRecargasTurnoProvider);
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : const Color(0xFFBAE6FD);
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;

    return recargasAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, stack) => const SizedBox.shrink(),
      data: (data) {
        final total = (data['total_monto'] as num?)?.toDouble() ?? 0.0;
        if (total <= 0) return const SizedBox.shrink();

        final ganancia = (data['total_ganancia'] as num?)?.toDouble() ?? 0.0;
        final cantidad = (data['cantidad'] as num?)?.toInt() ?? 0;

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF005CA9).withValues(alpha: esOscuro ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recargas Telefónicas del Turno',
                      style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$cantidad ${cantidad == 1 ? "recarga" : "recargas"} • Ganancia neta: Bs. ${ganancia.toStringAsFixed(2)}',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                'Bs. ${total.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF0284C7), fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 5. Sugerencias IA / Smart Bot (Motor Local 100% Offline)
  Widget _buildSmartBotCard(bool esOscuro) {
    final insightsAsync = ref.watch(sugerenciasInteligentesProvider);
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera Smart Engine
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: esOscuro ? const Color(0xFF2A1C4E) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: esOscuro ? const Color(0xFFB388FF) : const Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sugerencias Comerciales Inteligentes',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Motor IA local offline en SQLite',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esOscuro ? const Color(0xFF4C2A85) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SMART BOT',
                  style: TextStyle(
                    color: esOscuro ? Colors.white : const Color(0xFF7C3AED),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  ref.invalidate(sugerenciasInteligentesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Analizando rotación, stock y finanzas en tiempo real...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.refresh, color: textMuted, size: 18),
                tooltip: 'Actualizar sugerencias',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Contenido reactivo
          insightsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Evaluando compras, visitas y flujo semanal...',
                      style: TextStyle(color: textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Error al generar sugerencias: $err',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            data: (insights) {
              if (insights.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF0A2318) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: esOscuro
                          ? const Color(0xFF00E676).withValues(alpha: 0.3)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: esOscuro ? const Color(0xFF00E676) : AppColors.retailGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Todo en orden en la tienda',
                              style: TextStyle(
                                color: esOscuro ? Colors.white : const Color(0xFF14532D),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'No hay quiebres urgentes de proveedores, tus deudores están al día y las finanzas semanales se mantienen sanas.',
                              style: TextStyle(
                                color: esOscuro ? const Color(0xFF94A3B8) : const Color(0xFF15803D),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < insights.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildSugerenciaItem(insights[i], esOscuro),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciaItem(InsightModel insight, bool esOscuro) {
    final itemBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final itemBorder = insight.urgencia == NivelUrgencia.critico
        ? (esOscuro ? const Color(0xFFE11D48).withValues(alpha: 0.35) : const Color(0xFFFECDD3))
        : (esOscuro ? AppColors.darkBorder : AppColors.border);
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textDesc = esOscuro ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: itemBorder,
          width: insight.urgencia == NivelUrgencia.critico ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.icono, color: insight.badgeColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.titulo,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: insight.badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: insight.badgeColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  insight.badgeTexto,
                  style: TextStyle(
                    color: insight.badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.descripcion,
            style: TextStyle(
              color: textDesc,
              fontSize: 12,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 12),
          // Botones de acción contextual
          Row(
            children: [
              if (insight.tipoAccion != TipoAccionInsight.soloLectura) ...[
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: insight.tipoAccion == TipoAccionInsight.abrirCobroVecino
                            ? const Color(0xFF25D366)
                            : insight.tipoAccion == TipoAccionInsight.abrirPedidoProveedor
                                ? AppColors.retailBlue
                                : const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _ejecutarAccionInsight(insight),
                      icon: Icon(
                        insight.tipoAccion == TipoAccionInsight.abrirCobroVecino
                            ? Icons.mark_chat_unread_rounded
                            : insight.tipoAccion == TipoAccionInsight.abrirPedidoProveedor
                                ? Icons.send_rounded
                                : Icons.edit_note_rounded,
                        size: 16,
                      ),
                      label: Text(
                        insight.accionLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
              // Botón rápido de silenciar producto estacional
              if (insight.categoria == CategoriaInsight.rotacionLicores && insight.entidadId != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: esOscuro ? const Color(0xFF94A3B8) : AppColors.textMuted,
                      side: BorderSide(color: esOscuro ? const Color(0xFF334155) : AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _ejecutarAccionInsight(
                      insight.copyWith(tipoAccion: TipoAccionInsight.silenciarEstacional),
                    ),
                    icon: const Text('❄️', style: TextStyle(fontSize: 12)),
                    label: const Text(
                      'Es de Temporada',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 6. Formulario Integrado para Salida Rápida de Dinero
  Widget _buildFormularioGastoRapido(CajaTurnoModel turno, bool esOscuro) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final inputBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_circle_down_rounded, color: Color(0xFFFF5252), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Registrar Salida de Dinero de Caja (Gasto Rápido)',
                  style: TextStyle(
                    color: textPrimary,
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
            style: TextStyle(color: textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Concepto (ej. Compra de 2 bolsas de hielo)',
              hintStyle: TextStyle(color: textMuted, fontSize: 12.5),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: inputBorder),
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
            style: TextStyle(color: textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Monto (Bs.)',
              hintStyle: TextStyle(color: textMuted, fontSize: 12.5),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixText: 'Bs. ',
              prefixStyle: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: inputBorder),
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
                elevation: 0,
              ),
              onPressed: _guardandoGasto ? null : () => _registrarGastoRapido(turno),
              child: _guardandoGasto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Registrar Gasto',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
