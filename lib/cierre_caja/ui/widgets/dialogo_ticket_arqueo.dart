import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/caja_turno_model.dart';

class DialogoTicketArqueo extends StatelessWidget {
  final CajaTurnoModel turno;

  const DialogoTicketArqueo({super.key, required this.turno});

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '--:--';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dif = turno.diferencia ?? 0.0;
    final bool estaCuadrada = dif.abs() <= 1.0;
    final bool hayFaltante = dif < -1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado Ticket
              const Center(
                child: Icon(Icons.receipt_long, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'TIENDA DE BARRIO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
              const Center(
                child: Text(
                  'ACTA DE ARQUEO Y CIERRE DE CAJA',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
              const Divider(height: 24, thickness: 1.5),

              // Datos del Turno
              _FilaTicket(label: 'Estado:', valor: turno.estado, esNegrita: true),
              _FilaTicket(label: 'Apertura:', valor: _formatearFecha(turno.fechaApertura)),
              _FilaTicket(label: 'Cierre:', valor: _formatearFecha(turno.fechaCierre)),
              const Divider(height: 18),

              // Desglose de Operaciones
              _FilaTicket(
                label: 'Fondo Inicial:',
                valor: 'Bs. ${turno.montoInicial.toStringAsFixed(2)}',
              ),
              _FilaTicket(
                label: 'Ventas en Efectivo:',
                valor: '+ Bs. ${turno.totalVentasEfectivo.toStringAsFixed(2)}',
                colorValor: AppColors.success,
              ),
              _FilaTicket(
                label: 'Ventas por QR (Banco):',
                valor: 'Bs. ${turno.totalVentasQr.toStringAsFixed(2)}',
                colorValor: Colors.blue[700],
              ),
              _FilaTicket(
                label: 'Fiados Otorgados:',
                valor: 'Bs. ${turno.totalFiadosOtorgados.toStringAsFixed(2)}',
                colorValor: Colors.orange[800],
              ),
              _FilaTicket(
                label: 'Fiados Cobrados (Efectivo):',
                valor: '+ Bs. ${turno.totalFiadosCobradosEfectivo.toStringAsFixed(2)}',
                colorValor: AppColors.success,
              ),
              _FilaTicket(
                label: 'Ingresos Manuales:',
                valor: '+ Bs. ${turno.totalEntradasManuales.toStringAsFixed(2)}',
              ),
              _FilaTicket(
                label: 'Gastos / Salidas Manuales:',
                valor: '- Bs. ${turno.totalSalidasManuales.toStringAsFixed(2)}',
                colorValor: AppColors.danger,
              ),
              const Divider(height: 20, thickness: 1.5),

              // Comparativa y Resultado de Auditoría
              _FilaTicket(
                label: 'EFECTIVO ESPERADO:',
                valor: 'Bs. ${turno.montoEsperadoEfectivo.toStringAsFixed(2)}',
                esNegrita: true,
              ),
              _FilaTicket(
                label: 'EFECTIVO REAL CONTADO:',
                valor: 'Bs. ${(turno.montoRealContado ?? 0.0).toStringAsFixed(2)}',
                esNegrita: true,
                colorValor: AppColors.primary,
              ),
              const SizedBox(height: 10),

              // Tarjeta de Descuadre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: estaCuadrada
                      ? AppColors.success.withAlpha(25)
                      : (hayFaltante ? AppColors.danger.withAlpha(25) : AppColors.warning.withAlpha(25)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: estaCuadrada
                        ? AppColors.success
                        : (hayFaltante ? AppColors.danger : AppColors.warning),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      estaCuadrada ? 'CUADRE EXACTO' : (hayFaltante ? 'FALTANTE' : 'SOBRANTE'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: estaCuadrada
                            ? AppColors.success
                            : (hayFaltante ? AppColors.danger : AppColors.warning),
                      ),
                    ),
                    Text(
                      '${dif >= 0 ? '+' : ''}Bs. ${dif.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: estaCuadrada
                            ? AppColors.success
                            : (hayFaltante ? AppColors.danger : AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

              // Desglose de Denominaciones si existe
              if (turno.desgloseEfectivo != null && turno.desgloseEfectivo!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Conteo de Denominaciones:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: turno.desgloseEfectivo!.entries
                      .where((e) => e.value > 0)
                      .map(
                        (e) => Chip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text(
                            '${e.value}x Bs. ${e.key}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppColors.background,
                        ),
                      )
                      .toList(),
                ),
              ],

              if (turno.observacionesCierre != null && turno.observacionesCierre!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Observaciones: ${turno.observacionesCierre!}',
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Botón Cerrar
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ENTENDIDO / CERRAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaTicket extends StatelessWidget {
  final String label;
  final String valor;
  final bool esNegrita;
  final Color? colorValor;

  const _FilaTicket({
    required this.label,
    required this.valor,
    this.esNegrita = false,
    this.colorValor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: esNegrita ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: esNegrita ? FontWeight.bold : FontWeight.w600,
              color: colorValor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
