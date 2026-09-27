# Contexto y Decisiones de Negocio: Venta Fraccionada, Venta Dual y Empaques Mayoristas

Documento de memoria técnica y contexto funcional para el proyecto **SI Tienda de Barrio**.
Fecha de consolidación: Septiembre 2026.

---

## 📌 1. Visión y Problemática Resuelta

Las tiendas de barrio y licorerías familiares de Bolivia no operan únicamente con productos de código de barras empaquetados. Su operativa diaria incluye tres casuísticas críticas:

1. **Venta a granel / pesables (Pollo, Queso Criollo, Carne, Hoja de Coca, Azúcar, Arroz):**
   - El cliente suele pedir por **monto en dinero** (*"Deme 10 pesos de queso"*) o por **fracciones comunes** (*"Deme medio kilo de pollo"*), o bien se pesa directamente un artículo entero en la balanza (*"Este pollo pesó 1.845 kg"*).
2. **Venta dual al detalle (Cigarrillos, Medicamentos / Pastillas, Papel higiénico individual):**
   - El producto se compra al proveedor en caja o paquete cerrado, pero se vende al público tanto en su presentación original como en unidades sueltas (ej. 1, 2 o 3 cigarrillos individuales extraídos de la cajetilla), con un precio unitario mayor que genera un margen comercial superior.
3. **Reposición en empaques comerciales cerrados:**
   - El pedido al distribuidor mayorista no se realiza en unidades sueltas, sino en bultos estándar: **Cajas** (cervezas, aceite), **Paquetes** (six-pack de gaseosas), **Fardos/Jabas** (papel higiénico), **Tiras/Bolsas** (chicles, pastillas, rasuradoras) y **Kilos enteros** (pollo, queso, carne).

---

## 🎨 2. Decisiones de UX / UI (Accesibilidad Táctil para Personas Mayores)

Tras las pruebas en vivo en el navegador/emulador táctil, se establecieron las siguientes directrices estrictas:

### 2.1. Modal de Venta Fraccionada (`ModalVentaFraccionada`)
* **Ubicación:** `lib/punto_de_venta/ui/widgets/modal_venta_fraccionada.dart`
* **Un único recuadro principal de dinero:**
  * En la parte superior de la pantalla se muestra el importe en Bolivianos: **`Bs. [ 0.00 ]`**.
  * Permite edición directa o cálculo automático.
  * Justo debajo indica en tiempo real la equivalencia: *`Equivale a: X.XXX kg`*.
* **Venta rápida por peso:**
  * Fila de 4 botones táctiles grandes: **`[ ¼ kg ]`**, **`[ ½ kg ]`**, **`[ ¾ kg ]`**, **`[ 1 kg ]`** (o libras).
  * Al pulsar una fracción (ej. `½ kg`), el recuadro superior se actualiza de inmediato con el valor a cobrar.
* **Balanza desplegable bajo demanda:**
  * Botón: **`[ ⚖️ ¿Otro peso específico de balanza? (Tocar aquí) ▾ ]`**.
  * El teclado numérico táctil masivo (`1, 2, 3... ⌫`) **permanece oculto por defecto** para evitar sobrecargar la pantalla visualmente. Solo se despliega si el vendedor necesita ingresar un pesaje exacto proveniente de la balanza física.
* **Sin distracciones:** Se eliminaron los botones de monedas/billetes rápidos para maximizar el espacio y claridad del flujo.
* **Botón de confirmación masivo:** Altura ≥ 60dp con feedback claro del total antes de enviar al ticket.

### 2.2. Modal de Venta Dual (`ModalVentaDual`)
* **Ubicación:** `lib/punto_de_venta/ui/widgets/modal_venta_dual.dart`
* Permite seleccionar entre **Empaque Completo** (ej. Cajetilla de 20 cigarrillos a Bs. 15.00) o **Unidades Sueltas** (ej. Bs. 1.00 cada cigarrillo).
* Descuenta del stock la fracción matemática exacta `cantidad / unidadesEnEmpaqueVenta`, evitando descuadres contables y manteniendo la inmutabilidad de la base de datos.

---

## 📦 3. Lista de Reposición y Pedidos de WhatsApp

### 3.1. Regla de Kilos Enteros para Granel
* **Decisión de negocio acordada:** Para productos a granel/pesables (pollo, queso, carne, etc.), la sugerencia de compra al proveedor mayorista **siempre debe ser en KILOS ENTEROS** (números enteros redondeados hacia arriba con `ceilToDouble()`, ej. `5 kilos`, `10 kilos`, nunca números decimales como `3.42 kg`).
* Los controles de incremento `+` y decremento `-` avanzan de **1 en 1 kilo** con un mínimo de 1.
* El texto generado para WhatsApp indica claramente: `• Pedir: 5 kilos` (o libras).

### 3.2. Formateador de WhatsApp (`PedidoFormatter`)
* **Ubicación:** `lib/inventario/utils/pedido_formatter.dart`
* Genera un mensaje limpio, legible y profesional listo para enviar al distribuidor vía WhatsApp, desglosando cajas, paquetes, fardos y kilos enteros con sus subtotales de costo estimado.

---

## 🗄️ 4. Estructura de Datos (Migración SQL)

Archivo: `supabase/migrations/04_empaques_y_fraccionamiento.sql`

```sql
-- Empaques mayoristas
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS tipo_empaque VARCHAR(50) NOT NULL DEFAULT 'UNIDAD'
    CHECK (tipo_empaque IN ('UNIDAD', 'CAJA', 'PAQUETE', 'FARDO', 'BOLSA', 'TIRA', 'KILO', 'LIBRA')),
ADD COLUMN IF NOT EXISTS unidades_por_empaque NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS costo_por_empaque NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- Venta dual al detalle
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS permite_venta_suelta BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS nombre_unidad_suelta VARCHAR(50) NULL DEFAULT 'unidad',
ADD COLUMN IF NOT EXISTS unidades_en_empaque_venta NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS precio_venta_suelta NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
```

---

## 📂 5. Mapa de Archivos Implementados

| Archivo | Responsabilidad |
| :--- | :--- |
| `supabase/migrations/04_empaques_y_fraccionamiento.sql` | Esquema de columnas para empaques mayoristas y venta dual. |
| `lib/inventario/data/models/producto_model.dart` | Modelo `Producto` extendido con getters de empaque, cálculo de unidades faltantes y parsing seguro (`fromMap`). |
| `lib/inventario/data/models/item_reposicion_model.dart` | Modelo inmutable para ítems de reposición mayorista. |
| `lib/inventario/state/providers/reposicion_providers.dart` | Notifier y providers para gestión interactiva de la lista de compras y cálculo en enteros. |
| `lib/inventario/ui/screens/lista_reposicion_screen.dart` | Pantalla de lista de reposición con badge de stock bajo y acciones de WhatsApp. |
| `lib/inventario/utils/pedido_formatter.dart` | Utilidad de formato y lanzamiento a WhatsApp de órdenes mayoristas. |
| `lib/punto_de_venta/data/models/item_carrito_model.dart` | Modelo del carrito con soporte para modos: `normal`, `porPeso`, `suelta`. |
| `lib/punto_de_venta/state/providers/carrito_providers.dart` | Métodos `agregarFraccionado` y `agregarSuelto` para cálculo de stock fraccional. |
| `lib/punto_de_venta/ui/widgets/modal_venta_fraccionada.dart` | Modal de venta por peso: recuadro único de dinero, fracciones 1/4, 1/2, 3/4, 1 kg y balanza desplegable. |
| `lib/punto_de_venta/ui/widgets/modal_venta_dual.dart` | Modal para selección entre empaque entero y unidades sueltas. |
| `lib/inventario/ui/screens/catalogo_screen.dart` | Catálogo central con ruteo automático al modal correspondiente y acceso a movimientos. |
| `supabase/migrations/05_movimientos_y_desempaque.sql` | Tabla `movimientos_inventario`, trigger de inmutabilidad y funciones RPC atómicas. |
| `lib/inventario/data/models/movimiento_inventario_model.dart` | Modelo inmutable para auditoría de movimientos de inventario. |
| `lib/inventario/data/repositories/movimientos_repository.dart` | Repositorio con llamadas atómicas a RPCs de PostgreSQL en Supabase. |
| `lib/inventario/state/providers/movimientos_providers.dart` | StateNotifier y providers de Riverpod para control de transacciones de desempaque y merma. |
| `lib/inventario/ui/screens/movimientos_inventario_screen.dart` | Pantalla accesible con selector masivo (Desempaque / Mermas), previsualización de cambio de stock e historial. |

---

## 🔄 6. Módulo de Desempaque Mayorista y Mermas

### 6.1. Atomicidad Transaccional (PostgreSQL RPC)
* El desempaque de cajas a unidades sueltas se procesa mediante la función RPC `desempaquetar_producto(p_caja_id, p_unidades_id, p_cantidad_cajas, p_tenant_id)`.
* Bloquea las filas con `FOR UPDATE`, descuenta cajas, suma botellas y genera dos registros inmutables vinculados (`referencia_id`) en una sola transacción ACID.

### 6.2. Mermas con Impacto Financiero
* El registro de roturas o vencimientos calcula automáticamente el costo de pérdida en Bolivianos (`cantidad * costo_unitario`).
* Prohíbe borrados o modificaciones mediante el trigger `trg_prohibir_modificacion_movimientos`.

