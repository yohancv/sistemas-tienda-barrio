import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../data/models/cliente_model.dart';
import '../../data/repositories/clientes_repository.dart';

/// Proveedor del repositorio de clientes inyectando SupabaseClient
final clientesRepositoryProvider = Provider<ClientesRepository>((ref) {
  return ClientesRepository(SupabaseConfig.client);
});

/// Proveedor del término de búsqueda de clientes reactivo
final searchQueryClientesProvider = StateProvider<String>((ref) => '');

/// Filtro rápido para ver solo clientes que tienen saldo pendiente
final filtroSoloDeudoresProvider = StateProvider<bool>((ref) => false);

/// Proveedor base que consulta los clientes en Supabase
final clientesListProvider = FutureProvider<List<Cliente>>((ref) async {
  final repository = ref.watch(clientesRepositoryProvider);
  final query = ref.watch(searchQueryClientesProvider);
  const tenantId = SupabaseConfig.defaultTenantId;

  if (query.trim().isEmpty) {
    return repository.obtenerClientes(tenantId);
  } else {
    return repository.buscarClientes(tenantId, query);
  }
});

/// Proveedor filtrado reactivo
final clientesFiltradosProvider = Provider<AsyncValue<List<Cliente>>>((ref) {
  final clientesAsync = ref.watch(clientesListProvider);
  final soloDeudores = ref.watch(filtroSoloDeudoresProvider);

  return clientesAsync.whenData((clientes) {
    if (!soloDeudores) return clientes;
    return clientes.where((c) => c.tieneDeuda).toList();
  });
});

/// Monto total de deuda acumulada en la calle por cobrar (Bs.)
final totalDeudaCalleProvider = Provider<double>((ref) {
  final clientesAsync = ref.watch(clientesListProvider);
  return clientesAsync.maybeWhen(
    data: (clientes) => clientes.fold<double>(
      0.0,
      (acc, c) => acc + (c.tieneDeuda ? c.saldoActual : 0.0),
    ),
    orElse: () => 0.0,
  );
});

/// Total de personas que deben actualmente en la tienda
final conteoDeudoresProvider = Provider<int>((ref) {
  final clientesAsync = ref.watch(clientesListProvider);
  return clientesAsync.maybeWhen(
    data: (clientes) => clientes.where((c) => c.tieneDeuda).length,
    orElse: () => 0,
  );
});

/// Estado de operaciones de clientes y abonos
class ClienteOperacionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ClienteOperacionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ClienteOperacionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ClienteOperacionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Notifier para gestionar la creación rápida de clientes y registro de abonos
class ClientesNotifier extends StateNotifier<ClienteOperacionState> {
  final ClientesRepository _repository;
  final Ref _ref;

  ClientesNotifier(this._repository, this._ref)
      : super(const ClienteOperacionState());

  /// Crea un nuevo cliente en el sistema y retorna la instancia generada
  Future<Cliente?> crearCliente({
    required String nombre,
    String? telefono,
    double limiteCredito = 100.0,
    String? notas,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final nuevo = Cliente(
        id: '',
        tenantId: SupabaseConfig.defaultTenantId,
        nombre: nombre.trim(),
        telefono: telefono?.trim(),
        limiteCredito: limiteCredito,
        saldoActual: 0.0,
        notas: notas?.trim(),
        activo: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final clienteCreado = await _repository.crearCliente(nuevo);

      // Refrescar lista de clientes
      _ref.invalidate(clientesListProvider);

      state = state.copyWith(
        isLoading: false,
        successMessage: '¡Cliente "${clienteCreado.nombre}" registrado exitosamente!',
      );
      return clienteCreado;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al registrar cliente: $e',
      );
      return null;
    }
  }

  /// Registra un abono a deuda y actualiza el saldo del cliente
  Future<bool> registrarAbono({
    required String clienteId,
    required double monto,
    String metodoPago = 'EFECTIVO',
    String? notas,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final res = await _repository.registrarAbono(
        clienteId: clienteId,
        monto: monto,
        metodoPago: metodoPago,
        notas: notas,
        tenantId: SupabaseConfig.defaultTenantId,
      );

      _ref.invalidate(clientesListProvider);
      _ref.invalidate(resumenCajaTurnoProvider);

      final nuevoSaldo = (res['nuevo_saldo'] as num?)?.toDouble() ?? 0.0;
      final nombre = res['nombre_cliente'] ?? 'Cliente';

      state = state.copyWith(
        isLoading: false,
        successMessage:
            '¡Abono de Bs. ${monto.toStringAsFixed(2)} registrado para $nombre! Saldo restante: Bs. ${nuevoSaldo.toStringAsFixed(2)}',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void limpiarMensajes() {
    state = const ClienteOperacionState();
  }
}

final clientesNotifierProvider =
    StateNotifierProvider<ClientesNotifier, ClienteOperacionState>((ref) {
  final repo = ref.watch(clientesRepositoryProvider);
  return ClientesNotifier(repo, ref);
});
