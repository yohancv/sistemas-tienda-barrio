import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/config/supabase_client.dart';
import '../../../inventario/data/models/item_reposicion_model.dart';
import '../../../inventario/data/models/producto_model.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/state/providers/movimientos_providers.dart';
import '../../data/models/compra_model.dart';
import '../../data/models/item_compra_model.dart';
import '../../data/models/proveedor_model.dart';
import '../../data/repositories/compras_repository.dart';

/// Proveedor global del repositorio de compras
final comprasRepositoryProvider = Provider<ComprasRepository>((ref) {
  return ComprasRepository(SupabaseConfig.client);
});

/// Proveedor de la lista de proveedores activos
final proveedoresListProvider =
    FutureProvider<List<ProveedorModel>>((ref) async {
  final repo = ref.watch(comprasRepositoryProvider);
  return repo.obtenerProveedores(SupabaseConfig.defaultTenantId);
});

/// Estado inmutable del Carrito de Abastecimiento / Nueva Compra
class CarritoComprasState {
  final ProveedorModel? proveedorSeleccionado;
  final List<ItemCompraModel> items;
  final String numeroComprobante;
  final String observaciones;
  final String metodoPago; // 'EFECTIVO_CAJA', 'EFECTIVO_EXTERNO_ATM', 'QR_BANCO', 'PAGO_MIXTO'
  final double montoCaja;
  final double montoExterno;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const CarritoComprasState({
    this.proveedorSeleccionado,
    this.items = const [],
    this.numeroComprobante = '',
    this.observaciones = '',
    this.metodoPago = 'EFECTIVO_CAJA',
    this.montoCaja = 0.0,
    this.montoExterno = 0.0,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Inversión total de la compra en Bolivianos (Bs.)
  double get totalCompra =>
      items.fold(0.0, (acc, item) => acc + item.subtotal);

  /// Cantidad total de artículos/cajas a ingresar
  double get totalArticulos =>
      items.fold(0.0, (acc, item) => acc + item.cantidad);

  /// Cantidad de productos únicos en la lista
  int get totalProductosDistintos => items.length;

  bool get estaVacio => items.isEmpty;

  /// Valida que la suma de pagos cubra exactamente el total
  bool get esValidoPago {
    if (totalCompra <= 0) return false;
    return ((montoCaja + montoExterno) - totalCompra).abs() < 0.02;
  }

  /// Diferencia pendiente por asignar al pagar
  double get diferenciaPorPagar => totalCompra - (montoCaja + montoExterno);

  CarritoComprasState copyWith({
    ProveedorModel? proveedorSeleccionado,
    bool clearProveedor = false,
    List<ItemCompraModel>? items,
    String? numeroComprobante,
    String? observaciones,
    String? metodoPago,
    double? montoCaja,
    double? montoExterno,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return CarritoComprasState(
      proveedorSeleccionado: clearProveedor
          ? null
          : (proveedorSeleccionado ?? this.proveedorSeleccionado),
      items: items ?? this.items,
      numeroComprobante: numeroComprobante ?? this.numeroComprobante,
      observaciones: observaciones ?? this.observaciones,
      metodoPago: metodoPago ?? this.metodoPago,
      montoCaja: montoCaja ?? this.montoCaja,
      montoExterno: montoExterno ?? this.montoExterno,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Notifier que controla la preparación, edición y confirmación de la compra
class CarritoComprasNotifier extends StateNotifier<CarritoComprasState> {
  final ComprasRepository _repository;
  final Ref _ref;

  CarritoComprasNotifier(this._repository, this._ref)
      : super(const CarritoComprasState());

  void seleccionarProveedor(ProveedorModel? prov) {
    state = state.copyWith(
      proveedorSeleccionado: prov,
      clearProveedor: prov == null,
    );
  }

  void establecerComprobante(String valor) {
    state = state.copyWith(numeroComprobante: valor);
  }

  void establecerObservaciones(String valor) {
    state = state.copyWith(observaciones: valor);
  }

  /// Agrega un producto al carrito de compras
  void agregarProducto(Producto producto, {double cantidad = 1.0}) {
    final index = state.items.indexWhere((i) => i.productoId == producto.id);
    List<ItemCompraModel> nuevosItems;

    if (index >= 0) {
      final actual = state.items[index];
      final nuevaCant = actual.cantidad + cantidad;
      final actualizado = actual.copyWith(
        cantidad: nuevaCant,
        subtotal: nuevaCant * actual.costoUnitario,
      );
      nuevosItems = [...state.items];
      nuevosItems[index] = actualizado;
    } else {
      nuevosItems = [
        ...state.items,
        ItemCompraModel.desdeProducto(producto, cantidad: cantidad),
      ];
    }

    _actualizarItemsYRecalcularPagos(nuevosItems);
  }

  /// Carga múltiples productos procedentes de la Lista de Reposición
  void cargarDesdeListaReposicion({
    ProveedorModel? proveedor,
    required List<ItemReposicion> itemsReposicion,
  }) {
    final nuevosItems = itemsReposicion
        .where((r) => r.cantidadAComprar > 0)
        .map((r) => ItemCompraModel.desdeProducto(
              r.producto,
              cantidad: r.cantidadAComprar,
            ))
        .toList();

    state = state.copyWith(
      proveedorSeleccionado: proveedor,
      items: nuevosItems,
    );
    _recalcularPagosSegunMetodo(state.totalCompra);
  }

  /// Agrega automáticamente todos los productos con stock bajo del proveedor seleccionado
  void agregarTodosLosFaltantes(
    List<Producto> productosFaltantes, {
    Map<String, double> unidadesEnAlmacenMap = const {},
  }) {
    final nuevosItems = [...state.items];
    for (final prod in productosFaltantes) {
      final index = nuevosItems.indexWhere((i) => i.productoId == prod.id);
      final enAlmacen = unidadesEnAlmacenMap[prod.id] ?? 0.0;
      final stockTotal = prod.stockActual + enAlmacen;
      final faltante = (prod.stockMinimo - stockTotal) > 0
          ? (prod.stockMinimo - stockTotal)
          : (prod.tieneEmpaqueMayorista ? prod.unidadesPorEmpaque : 1.0);

      if (index >= 0) {
        final actual = nuevosItems[index];
        if (actual.cantidad < faltante) {
          nuevosItems[index] = actual.copyWith(
            cantidad: faltante,
            subtotal: faltante * actual.costoUnitario,
          );
        }
      } else {
        nuevosItems.add(ItemCompraModel.desdeProducto(prod, cantidad: faltante));
      }
    }
    _actualizarItemsYRecalcularPagos(nuevosItems);
  }

  /// Modifica la cantidad recibida de un producto
  void actualizarCantidad(String productoId, double cantidad) {
    if (cantidad <= 0) {
      eliminarItem(productoId);
      return;
    }

    final nuevos = state.items.map((i) {
      if (i.productoId == productoId) {
        return i.copyWith(
          cantidad: cantidad,
          subtotal: cantidad * i.costoUnitario,
        );
      }
      return i;
    }).toList();

    _actualizarItemsYRecalcularPagos(nuevos);
  }

  /// Actualiza el costo unitario de compra si varió
  void actualizarCosto(String productoId, double nuevoCosto) {
    if (nuevoCosto < 0) return;

    final nuevos = state.items.map((i) {
      if (i.productoId == productoId) {
        return i.copyWith(
          costoUnitario: nuevoCosto,
          subtotal: i.cantidad * nuevoCosto,
        );
      }
      return i;
    }).toList();

    _actualizarItemsYRecalcularPagos(nuevos);
  }

  /// Ajusta el nuevo precio de venta de mostrador sugerido
  void actualizarPrecioVenta(String productoId, double? nuevoPrecio) {
    final nuevos = state.items.map((i) {
      if (i.productoId == productoId) {
        return i.copyWith(
          nuevoPrecioVenta: nuevoPrecio,
          clearNuevoPrecio: nuevoPrecio == null || nuevoPrecio <= 0,
        );
      }
      return i;
    }).toList();

    state = state.copyWith(items: nuevos);
  }

  /// Elimina un producto de la compra (ej. entrega incompleta o sin stock en camión)
  void eliminarItem(String productoId) {
    final nuevos = state.items.where((i) => i.productoId != productoId).toList();
    _actualizarItemsYRecalcularPagos(nuevos);
  }

  /// Cambia el método de pago y auto-distribuye los importes
  void establecerMetodoPago(
    String metodo, {
    double efectivoCajaDisponible = 0.0,
  }) {
    final total = state.totalCompra;
    double caja = 0.0;
    double externo = 0.0;

    switch (metodo) {
      case 'EFECTIVO_CAJA':
        caja = total;
        externo = 0.0;
        break;
      case 'EFECTIVO_EXTERNO_ATM':
      case 'QR_BANCO':
        caja = 0.0;
        externo = total;
        break;
      case 'PAGO_MIXTO':
        // Si hay efectivo en caja, asignar hasta lo disponible y el resto a externo
        if (efectivoCajaDisponible > 0 && total > efectivoCajaDisponible) {
          caja = efectivoCajaDisponible;
          externo = total - efectivoCajaDisponible;
        } else {
          caja = total / 2;
          externo = total - caja;
        }
        break;
    }

    state = state.copyWith(
      metodoPago: metodo,
      montoCaja: caja,
      montoExterno: externo,
    );
  }

  void establecerMontoCaja(double monto) {
    state = state.copyWith(montoCaja: monto);
  }

  void establecerMontoExterno(double monto) {
    state = state.copyWith(montoExterno: monto);
  }

  void _actualizarItemsYRecalcularPagos(List<ItemCompraModel> nuevos) {
    state = state.copyWith(items: nuevos);
    _recalcularPagosSegunMetodo(state.totalCompra);
  }

  void _recalcularPagosSegunMetodo(double total) {
    switch (state.metodoPago) {
      case 'EFECTIVO_CAJA':
        state = state.copyWith(montoCaja: total, montoExterno: 0.0);
        break;
      case 'EFECTIVO_EXTERNO_ATM':
      case 'QR_BANCO':
        state = state.copyWith(montoCaja: 0.0, montoExterno: total);
        break;
      case 'PAGO_MIXTO':
        // Ajustar proporcionalmente o dejar montos si cuadran
        if ((state.montoCaja + state.montoExterno) == 0) {
          state = state.copyWith(montoCaja: total, montoExterno: 0.0);
        }
        break;
    }
  }

  void limpiarCarrito() {
    state = const CarritoComprasState();
  }

  /// Ejecuta la transacción atómica de compra en Supabase
  Future<bool> confirmarCompra({
    required String? cajaTurnoId,
    required double efectivoCajaDisponible,
  }) async {
    if (state.items.isEmpty) {
      state = state.copyWith(errorMessage: 'No hay productos en la orden de compra.');
      return false;
    }

    final total = state.totalCompra;
    if (total <= 0) {
      state = state.copyWith(errorMessage: 'El total de la compra debe ser mayor a Bs. 0.00.');
      return false;
    }

    // Validación 1: Cuadre estricto de pagos
    if (!state.esValidoPago) {
      state = state.copyWith(
        errorMessage:
            'La suma de pagos (Caja: Bs. ${state.montoCaja.toStringAsFixed(2)} + Externo: Bs. ${state.montoExterno.toStringAsFixed(2)}) no coincide con el total de Bs. ${total.toStringAsFixed(2)}.',
      );
      return false;
    }

    // Validación 2: Efectivo de caja disponible
    if (state.montoCaja > 0) {
      if (cajaTurnoId == null || cajaTurnoId.isEmpty) {
        state = state.copyWith(
          errorMessage:
              'No hay un turno de caja abierto para registrar el egreso de efectivo. Abre un turno o paga con dinero personal/QR.',
        );
        return false;
      }

      if (state.montoCaja > efectivoCajaDisponible) {
        state = state.copyWith(
          errorMessage:
              'Efectivo insuficiente en caja. Disponible: Bs. ${efectivoCajaDisponible.toStringAsFixed(2)}, solicitado: Bs. ${state.montoCaja.toStringAsFixed(2)}. Usa Pago Mixto o dinero externo.',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final compra = CompraModel(
        id: '',
        tenantId: SupabaseConfig.defaultTenantId,
        proveedorId: state.proveedorSeleccionado?.id,
        numeroComprobante: state.numeroComprobante.trim().isEmpty
            ? null
            : state.numeroComprobante.trim(),
        totalCompra: total,
        metodoPago: state.metodoPago,
        montoPagadoCaja: state.montoCaja,
        montoPagadoExterno: state.montoExterno,
        cajaTurnoId: state.montoCaja > 0 ? cajaTurnoId : null,
        observaciones: state.observaciones.trim().isEmpty
            ? null
            : state.observaciones.trim(),
        fechaCompra: DateTime.now(),
      );

      final res = await _repository.registrarCompraMercaderia(
        compra: compra,
        detalles: state.items,
      );

      // Invalidad proveedores reactivos
      _ref.invalidate(productosListProvider);
      _ref.invalidate(kardexListProvider);
      _ref.invalidate(historialMovimientosProvider);
      _ref.invalidate(historialComprasProvider);
      if (state.montoCaja > 0) {
        _ref.invalidate(resumenCajaTurnoProvider);
      }

      final itemsIngresados = res['items_count'] ?? state.items.length;
      final provNombre = state.proveedorSeleccionado?.nombreEmpresa ?? 'Proveedor';

      state = const CarritoComprasState().copyWith(
        successMessage:
            '¡Compra registrada con éxito! Se reabastecieron $itemsIngresados producto(s) de $provNombre (Total: Bs. ${total.toStringAsFixed(2)}).',
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
}

/// Proveedor del Notifier del carrito de compras
final carritoComprasProvider =
    StateNotifierProvider<CarritoComprasNotifier, CarritoComprasState>((ref) {
  final repo = ref.watch(comprasRepositoryProvider);
  return CarritoComprasNotifier(repo, ref);
});

/// Filtro del historial de compras
class HistorialComprasFiltro {
  final String? proveedorId;
  final DateTime? desde;
  final DateTime? hasta;

  const HistorialComprasFiltro({
    this.proveedorId,
    this.desde,
    this.hasta,
  });
}

final historialComprasFiltroProvider =
    StateProvider<HistorialComprasFiltro>((ref) {
  return const HistorialComprasFiltro();
});

/// Proveedor del historial de compras
final historialComprasProvider =
    FutureProvider<List<CompraModel>>((ref) async {
  final repo = ref.watch(comprasRepositoryProvider);
  final filtro = ref.watch(historialComprasFiltroProvider);

  return repo.obtenerHistorialCompras(
    SupabaseConfig.defaultTenantId,
    proveedorId: filtro.proveedorId,
    desde: filtro.desde,
    hasta: filtro.hasta,
  );
});
