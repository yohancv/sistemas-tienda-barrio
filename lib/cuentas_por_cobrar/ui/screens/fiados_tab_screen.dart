import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';
import '../widgets/modal_cobro_whatsapp.dart';
import '../widgets/modal_nuevo_cliente.dart';
import '../widgets/modal_registrar_abono.dart';
import '../widgets/modal_editar_cliente.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/debouncer.dart';

enum FiltroFiados { todos, soloDeuda, masDe15Dias }

/// Apartado 3: Fiados (Cuentas por Cobrar)
///
/// Características:
/// 1. En la parte superior: Total de fiados en la calle.
/// 2. Filtros: Todos, Con Deuda, +15 días sin pagar.
/// 3. Tarjetas de clientes con:
///    - Nombre, teléfono y semáforo de antigüedad.
///    - Historial con fecha y hora.
///    - Botón de Abono y Botón de Cobro directo por WhatsApp.
class FiadosTabScreen extends ConsumerStatefulWidget {
  const FiadosTabScreen({super.key});

  @override
  ConsumerState<FiadosTabScreen> createState() => _FiadosTabScreenState();
}

class _FiadosTabScreenState extends ConsumerState<FiadosTabScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(milliseconds: 220);
  String _debouncedQuery = '';
  FiltroFiados _filtro = FiltroFiados.soloDeuda;
  late final AnimationController _searchAnimController;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesListProvider);
    final totalDineroEnCalle = ref.watch(totalDineroEnLaCalleProvider);
    final conteoDeudores = ref.watch(conteoDeudoresProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);
    final query = _debouncedQuery;

    return Scaffold(
      backgroundColor: esOscuro ? AppColors.darkBackground : AppColors.background,
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar clientes: $err', style: const TextStyle(color: AppColors.danger)),
        ),
        data: (todosLosClientes) {
          final filtrados = todosLosClientes.where((c) {
            if (_filtro == FiltroFiados.soloDeuda && !c.tieneDeuda) return false;
            if (_filtro == FiltroFiados.masDe15Dias) {
              if (!c.tieneDeuda) return false;
              final dias = DateTime.now().difference(c.updatedAt).inDays;
              if (dias < 15) return false;
            }
            if (query.isNotEmpty) {
              final n = c.nombre.toLowerCase();
              final t = (c.telefono ?? '').toLowerCase();
              return n.contains(query) || t.contains(query);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // 1. PARTE SUPERIOR: Total Dinero Fiado en la Calle (Pure Clean Retail / Midnight Obsidian)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: esOscuro
                        ? const [AppColors.darkBannerStart, AppColors.darkBannerEnd]
                        : const [AppColors.bannerFiadosStart, AppColors.bannerFiadosEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL EN LA CALLE (FIADOS)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bs. ${totalDineroEnCalle.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$conteoDeudores',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'con deuda',
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Buscador y filtro rápido (se oculta automáticamente al hacer scroll hacia abajo)
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _searchAnimController,
                  curve: Curves.easeOutCubic,
                ),
                axisAlignment: -1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: esOscuro ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: esOscuro ? AppColors.darkBorder : AppColors.border,
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        onChanged: (val) {
                          _debouncer.run(() {
                            if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar vecino o teléfono...',
                          hintStyle: TextStyle(
                            color: esOscuro ? AppColors.darkTextMuted : AppColors.textMuted,
                            fontSize: 13.5,
                          ),
                          prefixIcon: Icon(Icons.search, color: esOscuro ? AppColors.darkAccent : AppColors.primary, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _debouncer.run(() {});
                                    setState(() => _debouncedQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: esOscuro ? AppColors.darkBorder : AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: esOscuro ? AppColors.darkBorder : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Con Deuda'),
                              selected: _filtro == FiltroFiados.soloDeuda,
                              selectedColor: esOscuro ? AppColors.darkAccent : AppColors.primary,
                              backgroundColor: esOscuro ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
                              labelStyle: TextStyle(
                                color: _filtro == FiltroFiados.soloDeuda
                                    ? (esOscuro ? AppColors.darkBackground : Colors.white)
                                    : (esOscuro ? AppColors.darkTextSecondary : AppColors.textPrimary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                AppHaptics.selection();
                                setState(() => _filtro = FiltroFiados.soloDeuda);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('⏰ +15 días sin pagar'),
                              selected: _filtro == FiltroFiados.masDe15Dias,
                              selectedColor: AppColors.danger,
                              backgroundColor: esOscuro ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
                              labelStyle: TextStyle(
                                color: _filtro == FiltroFiados.masDe15Dias
                                    ? Colors.white
                                    : (esOscuro ? AppColors.darkTextSecondary : AppColors.textPrimary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                AppHaptics.selection();
                                setState(() => _filtro = FiltroFiados.masDe15Dias);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Todos los Vecinos'),
                              selected: _filtro == FiltroFiados.todos,
                              selectedColor: esOscuro ? AppColors.darkAccent : AppColors.primary,
                              backgroundColor: esOscuro ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
                              labelStyle: TextStyle(
                                color: _filtro == FiltroFiados.todos
                                    ? (esOscuro ? AppColors.darkBackground : Colors.white)
                                    : (esOscuro ? AppColors.darkTextSecondary : AppColors.textPrimary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                AppHaptics.selection();
                                setState(() => _filtro = FiltroFiados.todos);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. LISTA DE RECUADROS DE CLIENTES CON HISTORIAL
              Expanded(
                child: filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron vecinos registrados',
                              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is UserScrollNotification) {
                            if (notification.direction == ScrollDirection.reverse) {
                              // Desplazamiento hacia abajo: ocultar buscador y teclado
                              FocusScope.of(context).unfocus();
                              if (_searchAnimController.status != AnimationStatus.reverse &&
                                  _searchAnimController.value > 0) {
                                _searchAnimController.reverse();
                              }
                            } else if (notification.direction == ScrollDirection.forward) {
                              // Desplazamiento hacia arriba: mostrar buscador
                              if (_searchAnimController.status != AnimationStatus.forward &&
                                  _searchAnimController.value < 1.0) {
                                _searchAnimController.forward();
                              }
                            }
                          }
                          // Si regresa arriba del todo de la lista, asegurar que esté visible
                          if (notification.metrics.pixels <= 10) {
                            if (_searchAnimController.value < 1.0 &&
                                _searchAnimController.status != AnimationStatus.forward) {
                              _searchAnimController.forward();
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final cliente = filtrados[index];
                            return _TarjetaClienteFiado(cliente: cliente);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),

      // Botón flotante para registrar nuevo vecino
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('NUEVO VECINO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final nuevo = await showModalBottomSheet<Cliente>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const ModalNuevoCliente(),
          );
          if (nuevo != null) {
            ref.invalidate(clientesListProvider);
          }
        },
      ),
    );
  }
}

/// Tarjeta individual de cliente con su deuda, último movimiento, mini-historial y 2 botones
class _TarjetaClienteFiado extends ConsumerStatefulWidget {
  final Cliente cliente;

  const _TarjetaClienteFiado({required this.cliente});

  @override
  ConsumerState<_TarjetaClienteFiado> createState() => _TarjetaClienteFiadoState();
}

class _TarjetaClienteFiadoState extends ConsumerState<_TarjetaClienteFiado> {
  List<Map<String, dynamic>>? _movimientos;
  bool _cargandoMovs = false;

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  Future<void> _cargarMovimientos() async {
    setState(() => _cargandoMovs = true);
    try {
      final repo = ref.read(clientesRepositoryProvider);
      final movs = await repo.obtenerMovimientosCliente(widget.cliente.id, limite: 3);
      if (mounted) setState(() => _movimientos = movs);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargandoMovs = false);
    }
  }

  Future<void> _abrirModalEditarCliente(BuildContext context, Cliente c) async {
    AppHaptics.light();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalEditarCliente(cliente: c),
    );
    ref.invalidate(clientesListProvider);
    _cargarMovimientos();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    final tieneDeuda = c.tieneDeuda;
    final esOscuro = ref.watch(esModoOscuroProvider);
    final semaforoColor = c.limiteSuperado
        ? AppColors.danger
        : (c.saldoActual > c.limiteCredito * 0.7 ? AppColors.warning : AppColors.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: c.limiteSuperado
              ? AppColors.danger
              : (esOscuro ? AppColors.darkBorder : AppColors.border),
          width: c.limiteSuperado ? 2 : 1,
        ),
      ),
      color: esOscuro ? AppColors.darkSurface : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Nombre + Deuda Pendiente + Semáforo Antigüedad + Límite
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.nombre,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _abrirModalEditarCliente(context, c),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: esOscuro ? Colors.white60 : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (c.telefono != null && c.telefono!.isNotEmpty) ...[
                            Text(
                              '📞 ${c.telefono}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _buildBadgeAntiguedad(c),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Pill de Límite de Fiado editable con 1 toque
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _abrirModalEditarCliente(context, c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.limiteSuperado
                                ? Colors.red.withValues(alpha: 0.1)
                                : (esOscuro ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: c.limiteSuperado
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : (esOscuro ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                size: 13,
                                color: c.limiteSuperado ? Colors.redAccent : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Límite: Bs. ${c.limiteCredito.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: esOscuro ? Colors.white70 : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• Disp: Bs. ${c.creditoDisponible.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.limiteSuperado ? Colors.redAccent : AppColors.retailGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 11, color: esOscuro ? Colors.white38 : AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Monto de deuda pendiente
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${c.saldoActual.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: tieneDeuda ? semaforoColor : AppColors.success,
                      ),
                    ),
                    Text(
                      tieneDeuda ? 'Deuda Pendiente' : 'Al día',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tieneDeuda ? semaforoColor : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: esOscuro ? AppColors.darkBorder : AppColors.border),
            const SizedBox(height: 10),

            // HISTORIAL CON FECHA Y HORA (Últimos 2-3 movimientos directos en la tarjeta)
            const Text(
              'HISTORIAL DE MOVIMIENTOS RECIENTES:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),

            if (_cargandoMovs)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_movimientos == null || _movimientos!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: esOscuro ? AppColors.darkBorder : AppColors.border),
                ),
                child: const Text(
                  'No hay movimientos recientes registrados para este cliente.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: esOscuro ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: _movimientos!.map((mov) {
                    final esAbono = mov['tipo'] == 'ABONO';
                    final monto = (mov['monto'] as num).toDouble();
                    final fecha = DateTime.tryParse(mov['fecha'] as String? ?? '') ?? DateTime.now();
                    final fechaHoraStr =
                        '${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, "0")}:${fecha.minute.toString().padLeft(2, "0")}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            esAbono ? Icons.check_circle : Icons.shopping_bag_outlined,
                            size: 16,
                            color: esAbono ? AppColors.success : AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              esAbono
                                  ? 'Abonó parte de la cuenta'
                                  : ((mov['productos_resumen'] as String?)?.isNotEmpty == true
                                      ? (mov['productos_resumen'] as String)
                                      : 'Sacó productos fiados'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: esOscuro ? const Color(0xFFE2E8F0) : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            fechaHoraStr,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${esAbono ? "-" : "+"} Bs. ${monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: esAbono ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            // BOTONES DE ACCIÓN: ABONAR, COBRO WHATSAPP Y VER HISTORIAL
            if (tieneDeuda) ...[
              Row(
                children: [
                  // Botón 1: Abonar / Pagó parte
                  Expanded(
                    flex: 5,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: esOscuro ? AppColors.darkSuccess : AppColors.success,
                        foregroundColor: esOscuro ? AppColors.darkSuccessDark : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.attach_money, size: 20),
                      label: const Text('ABONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ModalRegistrarAbono(cliente: c),
                        );
                        ref.invalidate(clientesListProvider);
                        _cargarMovimientos();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Botón 2: Cobrar por WhatsApp con mensaje pre-armado
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.mark_chat_unread_rounded, size: 18),
                      label: const Text('COBRAR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () async {
                        AppHaptics.medium();
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ModalCobroWhatsApp(cliente: c),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Ver historial completo de compras',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  onPressed: () => _mostrarHistorialCompleto(context, c),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('VER HISTORIAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _mostrarHistorialCompleto(context, c),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeAntiguedad(Cliente c) {
    if (!c.tieneDeuda) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('🟢 Al día', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
      );
    }

    final dias = DateTime.now().difference(c.updatedAt).inDays;
    if (dias <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('⚡ Movimiento hoy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
      );
    } else if (dias <= 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('⏳ Hace $dias d', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
      );
    } else if (dias <= 20) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('⚠️ $dias d sin abonar', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('🔴 Retrasado: $dias d', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger)),
      );
    }
  }

  void _mostrarHistorialCompleto(BuildContext context, Cliente c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Saldo actual: Bs. ${c.saldoActual.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Botón de WhatsApp amable
              if (c.tieneDeuda)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.mark_chat_unread_rounded, size: 18),
                      label: const Text(
                        'Cobrar por WhatsApp con Mensaje Personalizado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ModalCobroWhatsApp(cliente: c),
                        );
                      },
                    ),
                  ),
                ),

              const Text('Todos los movimientos registrados:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref.read(clientesRepositoryProvider).obtenerMovimientosCliente(c.id, limite: 50),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('Sin movimientos registrados aún'));
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final m = list[idx];
                        final esAbono = m['tipo'] == 'ABONO';
                        final monto = (m['monto'] as num).toDouble();
                        final fecha = DateTime.tryParse(m['fecha'] as String? ?? '') ?? DateTime.now();

                        final productos = m['productos_resumen'] as String?;
                        final titulo = esAbono
                            ? 'Abono recibido (${m['detalle'] ?? 'Efectivo'})'
                            : (productos != null && productos.isNotEmpty
                                ? productos
                                : 'Venta a crédito (Fiado)');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (esAbono ? AppColors.success : AppColors.danger).withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              esAbono ? Icons.check_circle_rounded : Icons.shopping_bag_rounded,
                              color: esAbono ? AppColors.success : AppColors.danger,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${esAbono ? "Abono a cuenta" : "Fiado"} • ${fecha.day}/${fecha.month}/${fecha.year} a las ${fecha.hour}:${fecha.minute.toString().padLeft(2, "0")}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: Text(
                            '${esAbono ? "-" : "+"} Bs. ${monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: esAbono ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
