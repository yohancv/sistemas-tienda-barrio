import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';
import '../../utils/cobro_whatsapp_formatter.dart';
import '../widgets/modal_nuevo_cliente.dart';
import '../widgets/modal_registrar_abono.dart';

class GestionFiadosScreen extends ConsumerStatefulWidget {
  const GestionFiadosScreen({super.key});

  @override
  ConsumerState<GestionFiadosScreen> createState() => _GestionFiadosScreenState();
}

class _GestionFiadosScreenState extends ConsumerState<GestionFiadosScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirNuevoCliente() async {
    final nuevo = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalNuevoCliente(),
    );

    if (!mounted) return;
    if (nuevo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('¡Vecino "${nuevo.nombre}" registrado!'),
        ),
      );
    }
  }

  void _abrirModalAbono(Cliente cliente) async {
    final abonado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalRegistrarAbono(cliente: cliente),
    );

    if (!mounted) return;
    if (abonado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('¡Abono registrado con éxito!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesFiltradosProvider);
    final totalDeuda = ref.watch(totalDeudaCalleProvider);
    final conteoDeudores = ref.watch(conteoDeudoresProvider);
    final soloDeudores = ref.watch(filtroSoloDeudoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cuentas por Cobrar (Fiados)',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, size: 28, color: Colors.white),
            tooltip: 'Registrar nuevo vecino',
            onPressed: () => _abrirNuevoCliente(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tarjeta Resumen: Total Dinero en la Calle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: totalDeuda > 0
                      ? AppColors.danger.withAlpha(15)
                      : AppColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: totalDeuda > 0
                        ? AppColors.danger.withAlpha(80)
                        : AppColors.success.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DEUDA EN LA CALLE:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bs. ${totalDeuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: totalDeuda > 0 ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$conteoDeudores',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'deudores',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Buscador y Filtro Rápido
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              color: AppColors.surface,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Buscar vecino por nombre...',
                      prefixIcon: const Icon(Icons.search, size: 26, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.danger),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchQueryClientesProvider.notifier).state = '';
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(searchQueryClientesProvider.notifier).state = val;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilterChip(
                        selected: soloDeudores,
                        label: Text(
                          soloDeudores ? 'Mostrando: Solo con deuda' : 'Ver solo con deuda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: soloDeudores ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selectedColor: AppColors.danger,
                        backgroundColor: AppColors.surfaceMuted,
                        onSelected: (val) {
                          ref.read(filtroSoloDeudoresProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Lista de Clientes
            Expanded(
              child: clientesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error: $err', style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
                data: (clientes) {
                  if (clientes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron clientes',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () => _abrirNuevoCliente(),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Registrar primer vecino',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: clientes.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = clientes[index];
                      return _ClienteCard(
                        cliente: c,
                        onAbonar: () => _abrirModalAbono(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta accesible de cada deudor con semáforo y accesos directos
class _ClienteCard extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onAbonar;

  const _ClienteCard({required this.cliente, required this.onAbonar});

  @override
  Widget build(BuildContext context) {
    final tieneDeuda = cliente.tieneDeuda;
    final semaforo = cliente.semaforo;

    Color colorBorde;
    Color colorFondoSem;
    String textoSem;

    switch (semaforo) {
      case SemaforoCredito.alDia:
        colorBorde = AppColors.border;
        colorFondoSem = AppColors.success;
        textoSem = 'Al Día';
        break;
      case SemaforoCredito.deudaNormal:
        colorBorde = AppColors.warning;
        colorFondoSem = AppColors.warning;
        textoSem = 'Fiado Activo';
        break;
      case SemaforoCredito.limiteAlcanzado:
        colorBorde = AppColors.danger;
        colorFondoSem = AppColors.danger;
        textoSem = 'Límite Superado';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde, width: tieneDeuda ? 2.0 : 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Nombre y Semáforo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cliente.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorFondoSem.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorFondoSem, width: 1.2),
                ),
                child: Text(
                  textoSem,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorFondoSem,
                  ),
                ),
              ),
            ],
          ),

          if (cliente.telefono != null && cliente.telefono!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  cliente.telefono!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],

          const Divider(height: 18),

          // Fila Central: Deuda y Límite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Adeudado:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  Text(
                    'Bs. ${cliente.saldoActual.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: tieneDeuda ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Límite de Fiado:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  Text(
                    'Bs. ${cliente.limiteCredito.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Disp: Bs. ${cliente.creditoDisponible.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cliente.limiteSuperado ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Fila Inferior: Botones de Acción
          Row(
            children: [
              // Botón de WhatsApp
              if (tieneDeuda) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.secondary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => CobroWhatsAppFormatter.enviarWhatsApp(cliente),
                  icon: const Icon(Icons.chat, color: AppColors.secondary, size: 20),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Botón Masivo de Abonar (52dp)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tieneDeuda ? AppColors.primary : AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: tieneDeuda ? onAbonar : null,
                    icon: Icon(
                      Icons.payment,
                      color: tieneDeuda ? Colors.white : AppColors.textMuted,
                      size: 22,
                    ),
                    label: Text(
                      tieneDeuda ? 'Registrar Abono' : 'Sin Deuda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tieneDeuda ? Colors.white : AppColors.textMuted,
                      ),
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
}
