import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item_reposicion_model.dart';
import '../../data/models/producto_model.dart';
import 'inventario_providers.dart';

/// Estado inmutable de la lista de reposición de compras
class ReposicionState {
  final List<ItemReposicion> items;
  final bool isInitialized;

  const ReposicionState({
    required this.items,
    this.isInitialized = false,
  });

  /// Inversión total estimada en Bolivianos (Bs.) requerida para reponer todo el pedido
  double get totalInversion =>
      items.fold(0.0, (acc, item) => acc + item.subtotalEstimado);

  /// Cantidad total de empaques/unidades a comprar
  double get totalArticulos =>
      items.fold(0.0, (acc, item) => acc + item.cantidadAComprar);

  /// Cantidad de productos únicos en la lista
  int get totalProductosDistintos => items.length;

  /// Indica si no hay productos pendientes de compra
  bool get estaVacia => items.isEmpty;

  ReposicionState copyWith({
    List<ItemReposicion>? items,
    bool? isInitialized,
  }) {
    return ReposicionState(
      items: items ?? this.items,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Notifier que controla la manipulación interactiva de cantidades y productos en la orden de reposición.
/// Si el producto tiene empaque mayorista, la cantidad se cuenta en empaques cerrados.
class ReposicionNotifier extends StateNotifier<ReposicionState> {
  ReposicionNotifier() : super(const ReposicionState(items: []));

  /// Inicializa o actualiza la lista basándose en los productos con stock bajo detectados.
  /// Si el producto tiene empaque mayorista, sugiere empaques cerrados.
  void sincronizarConProductos(List<Producto> productosBajos) {
    final Map<String, double> cantidadesPrevias = {
      for (final item in state.items) item.id: item.cantidadAComprar,
    };

    final nuevosItems = productosBajos.map((p) {
      final sugerida = _calcularCantidadSugerida(p);
      final cantidadFinal = cantidadesPrevias[p.id] ?? sugerida;

      return ItemReposicion(
        producto: p,
        cantidadSugerida: sugerida,
        cantidadAComprar: cantidadFinal,
      );
    }).toList();

    state = ReposicionState(
      items: nuevosItems,
      isInitialized: true,
    );
  }

  /// Calcula la cantidad sugerida de compra en la unidad correcta:
  /// - Si tiene empaque mayorista → empaques cerrados (redondeando arriba)
  /// - Si no → unidades sueltas
  static double _calcularCantidadSugerida(Producto p) {
    if (p.unidadesFaltantes <= 0) return 1.0;

    if (p.tieneEmpaqueMayorista && p.unidadesPorEmpaque > 0) {
      // Redondear hacia arriba para no quedarse corto
      return (p.unidadesFaltantes / p.unidadesPorEmpaque).ceilToDouble();
    }
    // Para productos a granel/pesables, la sugerencia de compra siempre es un número entero de kilos/libras
    if (p.esFraccionable) {
      return p.unidadesFaltantes.ceilToDouble();
    }
    return p.unidadesFaltantes;
  }

  /// Incrementa la cantidad a comprar
  void incrementarCantidad(String productoId, [double paso = 1.0]) {
    final updated = state.items.map((item) {
      if (item.id == productoId) {
        return item.copyWith(cantidadAComprar: item.cantidadAComprar + paso);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Reduce la cantidad a comprar sin permitir que caiga por debajo de 1
  void decrementarCantidad(String productoId, [double paso = 1.0]) {
    final updated = state.items.map((item) {
      if (item.id == productoId) {
        final nuevaCantidad = item.cantidadAComprar - paso;
        const limiteInferior = 1.0;
        return item.copyWith(
          cantidadAComprar: nuevaCantidad > limiteInferior ? nuevaCantidad : limiteInferior,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Modifica explícitamente la cantidad a comprar
  void actualizarCantidad(String productoId, double nuevaCantidad) {
    if (nuevaCantidad <= 0) return;
    final updated = state.items.map((item) {
      if (item.id == productoId) {
        return item.copyWith(cantidadAComprar: nuevaCantidad);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Quita temporalmente un producto de la lista de reposición
  void descartarProducto(String productoId) {
    final updated = state.items.where((item) => item.id != productoId).toList();
    state = state.copyWith(items: updated);
  }

  /// Restaura todas las cantidades recomendadas por el algoritmo
  void restaurarSugeridos(List<Producto> productosBajos) {
    final items = productosBajos.map((p) {
      final sugerida = _calcularCantidadSugerida(p);
      return ItemReposicion(
        producto: p,
        cantidadSugerida: sugerida,
        cantidadAComprar: sugerida,
      );
    }).toList();

    state = ReposicionState(items: items, isInitialized: true);
  }

  /// Indica si el notifier ya fue inicializado con los productos de inventario
  bool get isInitialized => state.isInitialized;
}

/// Proveedor global reactivo de la lista de reposición
final reposicionProvider =
    StateNotifierProvider<ReposicionNotifier, ReposicionState>((ref) {
  final notifier = ReposicionNotifier();
  final productosBajos = ref.watch(productosStockBajoListProvider);

  if (productosBajos.isNotEmpty && !notifier.isInitialized) {
    notifier.sincronizarConProductos(productosBajos);
  }

  return notifier;
});
