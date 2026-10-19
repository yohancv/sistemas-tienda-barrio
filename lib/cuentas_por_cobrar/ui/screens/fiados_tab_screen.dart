import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';
import '../../utils/cobro_whatsapp_formatter.dart';
import '../widgets/modal_nuevo_cliente.dart';
import '../widgets/modal_registrar_abono.dart';

/// Apartado 3: Fiados (Cuentas por Cobrar)
///
/// Características solicitadas:
/// 1. En la parte superior: Total de fiados (cuánto en total nos deben los vecinos).
/// 2. Tarjetas de clientes:
///    - Nombre del cliente y deuda pendiente.
///    - Último movimiento registrado.
///    - Historial con fecha y hora (si sacó fiado o abonó a la cuenta).
///    - Dos botones:
///      * Botón si pagó parte de su deuda (Abonar).
///      * Botón para ver el historial completo (y cobrar por WhatsApp).
class FiadosTabScreen extends ConsumerStatefulWidget {
  const FiadosTabScreen({super.key});

  @override
  ConsumerState<FiadosTabScreen> createState() => _FiadosTabScreenState();
}

class _FiadosTabScreenState extends ConsumerState<FiadosTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _soloConDeuda = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesListProvider);
    final totalDineroEnCalle = ref.watch(totalDineroEnLaCalleProvider);
    final conteoDeudores = ref.watch(conteoDeudoresProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar clientes: $err', style: const TextStyle(color: AppColors.danger)),
        ),
        data: (todosLosClientes) {
          final filtrados = todosLosClientes.where((c) {
            if (_soloConDeuda && !c.tieneDeuda) return false;
            if (query.isNotEmpty) {
              final n = c.nombre.toLowerCase();
              final t = (c.telefono ?? '').toLowerCase();
              return n.contains(query) || t.contains(query);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // 1. PARTE SUPERIOR: Total Dinero Fiado en la Calle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB45309), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.shade900.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bs. ${totalDineroEnCalle.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$conteoDeudores',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'con deuda',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Buscador y filtro rápido
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar vecino o teléfono...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(
                        'Solo deuda',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _soloConDeuda ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: _soloConDeuda,
                      selectedColor: AppColors.primary,
                      onSelected: (val) => setState(() => _soloConDeuda = val),
                    ),
                  ],
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
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) {
                          final cliente = filtrados[index];
                          return _TarjetaClienteFiado(cliente: cliente);
                        },
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

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    final tieneDeuda = c.tieneDeuda;
    final semaforoColor = c.limiteSuperado
        ? AppColors.danger
        : (c.saldoActual > c.limiteCredito * 0.7 ? AppColors.warning : AppColors.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: c.limiteSuperado ? const BorderSide(color: AppColors.danger, width: 2) : BorderSide.none,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Nombre + Deuda Pendiente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (c.telefono != null && c.telefono!.isNotEmpty)
                        Text(
                          '📞 ${c.telefono}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
            const Divider(height: 1),
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
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No hay movimientos recientes registrados para este cliente.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
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
                              esAbono ? 'Abonó parte de la cuenta' : 'Sacó productos fiados',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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

            // DOS BOTONES DE ACCIÓN:
            // [ 1. Botón si pagó parte de su deuda (Abonar) ] | [ 2. Botón de ver el historial ]
            Row(
              children: [
                // Botón 1: Abonar / Pagó parte
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.attach_money, size: 20),
                    label: const Text('ABONAR / PAGÓ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

                // Botón 2: Ver Historial completo
                Expanded(
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
            ),
          ],
        ),
      ),
    );
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
              if (c.telefono != null && c.telefono!.isNotEmpty && c.tieneDeuda)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D),
                        side: const BorderSide(color: Color(0xFF15803D)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Enviar Recordatorio Amable por WhatsApp'),
                      onPressed: () => CobroWhatsAppFormatter.enviarRecordatorio(
                        cliente: c,
                        nombreTienda: 'Tienda de Barrio',
                      ),
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

                        return ListTile(
                          leading: Icon(
                            esAbono ? Icons.check_circle : Icons.shopping_cart,
                            color: esAbono ? AppColors.success : AppColors.danger,
                          ),
                          title: Text(esAbono ? 'Abono recibido' : 'Venta a crédito (Fiado)',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Fecha: ${fecha.day}/${fecha.month}/${fecha.year} a las ${fecha.hour}:${fecha.minute.toString().padLeft(2, "0")}',
                          ),
                          trailing: Text(
                            '${esAbono ? "-" : "+"} Bs. ${monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
