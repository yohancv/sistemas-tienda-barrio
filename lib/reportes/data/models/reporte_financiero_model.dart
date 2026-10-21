import '../../../inventario/data/models/producto_model.dart';

/// Período de tiempo para el análisis financiero
enum PeriodoFiltroReporte {
  hoy,
  estaSemana,
  esteMes,
}

/// Resumen financiero global de un período con distinción entre dinero en mano y fiados
class ReporteFinancieroModel {
  final double ventasTotales;              // Total de ventas (contado + fiados)
  final double ventasCobradas;             // Ventas cobradas al contado (Efectivo + QR)
  final double ventasFiadas;               // Ventas entregadas a fiado
  final double totalAbonosCobrados;        // Deudas cobradas vía abonos

  final double totalEfectivoVentas;        // Efectivo directo de ventas
  final double totalEfectivoAbonos;        // Efectivo ingresado por abonos
  final double totalDineroEnCaja;          // Total efectivo físico en cajón (ventas + abonos)

  final double totalQrVentas;              // QR directo de ventas
  final double totalQrAbonos;              // QR ingresado por abonos
  final double totalDineroEnBanco;         // Total saldo en banco por QR (ventas + abonos)

  final double totalCobradoReal;           // Dinero real total ingresado (caja + banco)

  final double costoTotalMercaderia;       // Costo total de toda la mercadería entregada
  final double costoMercaderiaCobrada;     // Costo de la mercadería cobrada
  final double costoMercaderiaFiada;       // Costo de mercadería que está en la calle en fiados

  final double totalMermas;                // Pérdidas por rotura, vencimiento o ajustes negativos
  final double totalGastosTienda;          // Gastos operativos de tienda (servicios, bolsas, ayudante)

  final double gananciaCobradaEnMano;      // Ganancia bruta cobrada + abonos - mermas
  final double utilidadNetaBalance;        // UTILIDAD NETA DEL BALANCE = gananciaCobradaEnMano - totalGastosTienda
  final double gananciaPendienteFiados;    // Ganancia en la calle que se cobrará al pagar las deudas
  final double gananciaTotalProyectada;    // Utilidad del balance si se cobran todos los fiados
  final double margenCobradoPorcentaje;    // Margen % sobre lo efectivamente cobrado

  final int totalTransacciones;
  final int totalArticulosVendidos;

  const ReporteFinancieroModel({
    required this.ventasTotales,
    required this.ventasCobradas,
    required this.ventasFiadas,
    required this.totalAbonosCobrados,
    required this.totalEfectivoVentas,
    required this.totalEfectivoAbonos,
    required this.totalDineroEnCaja,
    required this.totalQrVentas,
    required this.totalQrAbonos,
    required this.totalDineroEnBanco,
    required this.totalCobradoReal,
    required this.costoTotalMercaderia,
    required this.costoMercaderiaCobrada,
    required this.costoMercaderiaFiada,
    required this.totalMermas,
    required this.totalGastosTienda,
    required this.gananciaCobradaEnMano,
    required this.utilidadNetaBalance,
    required this.gananciaPendienteFiados,
    required this.gananciaTotalProyectada,
    required this.margenCobradoPorcentaje,
    required this.totalTransacciones,
    required this.totalArticulosVendidos,
  });

  bool get esBalancePositivo => utilidadNetaBalance >= 0;

  // Compatibilidad hacia atrás si algún getter antiguo es invocado
  double get totalEfectivo => totalDineroEnCaja;
  double get totalQr => totalDineroEnBanco;
  double get totalFiado => ventasFiadas;
  double get gananciaNetaReal => utilidadNetaBalance;
  double get margenPorcentaje => margenCobradoPorcentaje;

  factory ReporteFinancieroModel.vacio() {
    return const ReporteFinancieroModel(
      ventasTotales: 0.0,
      ventasCobradas: 0.0,
      ventasFiadas: 0.0,
      totalAbonosCobrados: 0.0,
      totalEfectivoVentas: 0.0,
      totalEfectivoAbonos: 0.0,
      totalDineroEnCaja: 0.0,
      totalQrVentas: 0.0,
      totalQrAbonos: 0.0,
      totalDineroEnBanco: 0.0,
      totalCobradoReal: 0.0,
      costoTotalMercaderia: 0.0,
      costoMercaderiaCobrada: 0.0,
      costoMercaderiaFiada: 0.0,
      totalMermas: 0.0,
      totalGastosTienda: 0.0,
      gananciaCobradaEnMano: 0.0,
      utilidadNetaBalance: 0.0,
      gananciaPendienteFiados: 0.0,
      gananciaTotalProyectada: 0.0,
      margenCobradoPorcentaje: 0.0,
      totalTransacciones: 0,
      totalArticulosVendidos: 0,
    );
  }
}

/// Producto estrella dentro del Top de más vendidos
class TopProductoReporteModel {
  final String productoId;
  final String nombre;
  final String? categoria;
  final double cantidadVendida;
  final double totalVenta;
  final double costoTotal;
  final double gananciaAportada;

  const TopProductoReporteModel({
    required this.productoId,
    required this.nombre,
    this.categoria,
    required this.cantidadVendida,
    required this.totalVenta,
    required this.costoTotal,
    required this.gananciaAportada,
  });

  String get emoji => Producto.emojiCategoria(categoria);
}

/// Desglose de ingresos y ganancias por categoría
class CategoriaVentaReporteModel {
  final String categoria;
  final double totalVenta;
  final double totalGanancia;
  final double porcentajeDelTotal;

  const CategoriaVentaReporteModel({
    required this.categoria,
    required this.totalVenta,
    required this.totalGanancia,
    required this.porcentajeDelTotal,
  });

  String get emoji => Producto.emojiCategoria(categoria);
}

/// Paquete completo de datos para el Dashboard
class DashboardReporteCompleto {
  final PeriodoFiltroReporte periodo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final ReporteFinancieroModel financiero;
  final List<TopProductoReporteModel> topProductos;
  final List<CategoriaVentaReporteModel> ventasPorCategoria;

  const DashboardReporteCompleto({
    required this.periodo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.financiero,
    required this.topProductos,
    required this.ventasPorCategoria,
  });
}
