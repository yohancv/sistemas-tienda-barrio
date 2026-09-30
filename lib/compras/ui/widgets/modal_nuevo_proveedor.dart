import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/proveedor_model.dart';
import '../../state/providers/compras_providers.dart';

/// Modal para registrar o editar un proveedor/distribuidor
class ModalNuevoProveedor extends ConsumerStatefulWidget {
  final ProveedorModel? proveedorParaEditar;

  const ModalNuevoProveedor({
    super.key,
    this.proveedorParaEditar,
  });

  @override
  ConsumerState<ModalNuevoProveedor> createState() => _ModalNuevoProveedorState();
}

class _ModalNuevoProveedorState extends ConsumerState<ModalNuevoProveedor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _empresaController;
  late final TextEditingController _contactoController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _nitController;
  late final TextEditingController _diasVisitaController;

  final List<String> _diasSemanales = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];
  final Set<String> _diasSeleccionados = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedorParaEditar;
    _empresaController = TextEditingController(text: p?.nombreEmpresa ?? '');
    _contactoController = TextEditingController(text: p?.nombreContacto ?? '');
    _telefonoController = TextEditingController(text: p?.telefono ?? '');
    _nitController = TextEditingController(text: p?.nitCi ?? '');
    _diasVisitaController = TextEditingController(text: p?.diasVisita ?? '');

    if (p?.diasVisita != null) {
      for (final dia in _diasSemanales) {
        if (p!.diasVisita!.toLowerCase().contains(dia.toLowerCase())) {
          _diasSeleccionados.add(dia);
        }
      }
    }
  }

  @override
  void dispose() {
    _empresaController.dispose();
    _contactoController.dispose();
    _telefonoController.dispose();
    _nitController.dispose();
    _diasVisitaController.dispose();
    super.dispose();
  }

  void _toggleDia(String dia) {
    setState(() {
      if (_diasSeleccionados.contains(dia)) {
        _diasSeleccionados.remove(dia);
      } else {
        _diasSeleccionados.add(dia);
      }
      _diasVisitaController.text = _diasSeleccionados.join(' y ');
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final repo = ref.read(comprasRepositoryProvider);

    try {
      final p = widget.proveedorParaEditar;
      final nuevo = ProveedorModel(
        id: p?.id ?? '',
        tenantId: SupabaseConfig.defaultTenantId,
        nombreEmpresa: _empresaController.text.trim(),
        nombreContacto: _contactoController.text.trim().isEmpty
            ? null
            : _contactoController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        nitCi: _nitController.text.trim().isEmpty ? null : _nitController.text.trim(),
        diasVisita: _diasVisitaController.text.trim().isEmpty
            ? null
            : _diasVisitaController.text.trim(),
        activo: true,
        createdAt: p?.createdAt ?? DateTime.now(),
      );

      ProveedorModel resultado;
      if (p != null) {
        resultado = await repo.editarProveedor(nuevo);
      } else {
        resultado = await repo.crearProveedor(nuevo);
      }

      ref.invalidate(proveedoresListProvider);

      if (mounted) {
        Navigator.pop(context, resultado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error al guardar proveedor: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.proveedorParaEditar != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        esEdicion ? 'Editar Proveedor' : 'Nuevo Proveedor',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nombre de Empresa (Obligatorio)
              TextFormField(
                controller: _empresaController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre de Empresa / Distribuidor *',
                  hintText: 'ej. Cervecería Boliviana Nacional - CBN',
                  prefixIcon: const Icon(Icons.business_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el nombre de la empresa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Nombre del Preventista / Contacto
              TextFormField(
                controller: _contactoController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Preventista / Vendedor (Opcional)',
                  hintText: 'ej. Carlos Gómez',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Teléfono / Celular WhatsApp
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono / WhatsApp',
                  hintText: 'ej. 77712345',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Días de Visita de Preventistas
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Días de visita del preventista:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _diasSemanales.map((dia) {
                      final sel = _diasSeleccionados.contains(dia);
                      return FilterChip(
                        label: Text(dia),
                        selected: sel,
                        selectedColor: AppColors.primary.withAlpha(30),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: sel ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => _toggleDia(dia),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _diasVisitaController,
                    decoration: InputDecoration(
                      hintText: 'O escribe: ej. Lunes por la mañana y Jueves',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // NIT / CI (Opcional)
              TextFormField(
                controller: _nitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'NIT / CI (Opcional)',
                  hintText: 'ej. 1020304050',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Botón Guardar
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _guardar,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Guardando...' : (esEdicion ? 'Actualizar Proveedor' : 'Crear Proveedor'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
