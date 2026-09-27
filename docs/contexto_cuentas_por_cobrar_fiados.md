# Contexto y Decisiones de Negocio: Módulo de Cuentas por Cobrar (Deudores / Fiados)

Documento de memoria técnica y contexto funcional para el proyecto **SI Tienda de Barrio**.
Fecha de consolidación: Septiembre 2026.

---

## 📌 1. Visión y Problemática Resuelta

En las tiendas de barrio y pulperías de Bolivia, el crédito informal ("el fiado") es el pilar de fidelización con los vecinos de la zona. Históricamente, este control se realiza en un cuaderno o libreta física ("la libreta de fiados"), lo que ocasiona:
1. **Pérdida de dinero por descontrol:** Deudas olvidadas, sumas erradas o libretas extraviadas.
2. **Morosidad sin límites claros:** Se continúa fiando a vecinos que ya acumulan deudas excesivas sin que el dueño lo note al momento del cobro.
3. **Cobro incómodo o conflictivo:** Dificultad para recordar con amabilidad y precisión el saldo exacto adeudado a los vecinos.
4. **Descuadre de caja:** Cuando un cliente abona dinero a su deuda previa, se suele confundir ese ingreso con las ventas del día corriente.

---

## ⚖️ 2. Reglas de Negocio Estrictas y Auditoría

1. **Inmutabilidad Financiera de Abonos (`abonos_deuda`):**
   - La tabla `abonos_deuda` prohíbe terminantemente `UPDATE` y `DELETE` mediante el trigger `trg_prohibir_modificacion_abonos`.
   - Si un abono se registró por error, la auditoría exige registrar una transacción correctiva inversa, garantizando trazabilidad total para el dueño.
2. **Sincronización Automática de Saldo en PostgreSQL:**
   - **Venta a Fiado (`trg_sincronizar_saldo_cliente_por_venta`):** Cuando se confirma una venta con `metodo_pago = 'CREDITO_FIADO'`, el trigger suma automáticamente el monto total al `saldo_actual` del cliente.
   - **Abono Parcial o Total (`trg_sincronizar_saldo_cliente_por_abono`):** Cada nuevo abono registrado resta automáticamente el monto del `saldo_actual` del cliente.
   - Esto garantiza consistencia contable matemática sin depender de cálculos volátiles en el cliente móvil.
3. **Control Preventivo de Límite de Crédito:**
   - Cada cliente posee un `limite_credito` en Bolivianos (configurable, por defecto Bs. 100.00).
   - En la pantalla de cobro del POS, al seleccionar al cliente, el sistema calcula en tiempo real si `saldo_actual + total_venta > limite_credito`. Si se supera, advierte en rojo con un bloqueo de seguridad que requiere confirmación explícita del dueño.

---

## 🎨 3. Decisiones de UX / UI (Accesibilidad Táctil para Personas Mayores)

### 3.1. Pantalla de Cobro en Punto de Venta (`CobroScreen`)
* **Pestañas de Pago:** Efectivo, QR y Fiado.
* **Flujo Sin Pérdida de Ticket:** Si el vecino no estaba registrado, el cajero puede pulsar `➕ Registrar Nuevo Vecino Aquí` directamente desde la pantalla de cobro. Se abre un modal de 5 segundos, se guarda el cliente y regresa con el cliente preseleccionado sin perder los productos del carrito.
* **Indicadores Visuales Claros:** Muestra el saldo actual del cliente, el límite de crédito disponible y el nuevo saldo proyectado con colores semáforo.

### 3.2. Gestión de Fiados (`GestionFiadosScreen`)
* **Tarjeta Resumen Superior:** Muestra de un vistazo el **Total Dinero en la Calle** (`Bs. X.XX`) y el número de vecinos con deuda activa.
* **Búsqueda Instantánea y Filtro Rápido:** Permite buscar por nombre o teléfono, o activar el switch `Solo con deuda pendiente`.
* **Semáforo de Crédito:**
  - 🟢 **Bajo control:** Deuda < 50% del límite.
  - 🟡 **Atención:** Deuda entre 50% y 85% del límite.
  - 🟠 **Alerta:** Deuda entre 85% y 100% del límite.
  - 🔴 **Límite Excedido:** Deuda > 100% del límite.
* **Botones de Acción Inmediata (Touch Target ≥ 56dp):**
  - **Abonar:** Abre el modal de liquidación/abono.
  - **WhatsApp:** Genera y abre el mensaje de cobro amable y respetuoso.

### 3.3. Modal de Abonos Rápidos (`ModalRegistrarAbono`)
* **Botón Masivo de Liquidación Total:** Sugiere liquidar la deuda completa en un solo toque (`[ 💰 Liquidar Todo: Bs. X.XX ]`).
* **Atajos de Billetes Bolivianos:** Botones táctiles de `[ +10 Bs ]`, `[ +20 Bs ]`, `[ +50 Bs ]`, `[ +100 Bs ]` para agilizar el ingreso sin escribir.
* **Vista Previa de Saldo Restante:** Calcula instantáneamente cuánto le quedará debiendo el cliente antes de presionar confirmar.

### 3.4. Mensajería Amable por WhatsApp (`CobroWhatsAppFormatter`)
* Genera un saludo respetuoso y no agresivo acorde a la idiosincrasia boliviana:
  > *"Buenas tardes estimado(a) Don/Doña [Nombre]. Le saludamos de la Tienda de Barrio. Pasamos a recordarle amablemente que su saldo pendiente es de Bs. [Saldo]. ¡Muchas gracias por su preferencia!"*
* Se abre directamente en la app de WhatsApp del teléfono o mediante `wa.me/591[telefono]`.

---

## 🗄️ 4. Estructura de Base de Datos (`06_clientes_y_fiados.sql`)

### Tablas:
1. `public.clientes`:
   - `id`, `tenant_id`, `nombre`, `telefono`, `limite_credito`, `saldo_actual`, `notas`, `activo`, `created_at`, `updated_at`.
2. `public.abonos_deuda`:
   - `id`, `tenant_id`, `cliente_id`, `monto`, `metodo_pago`, `notas`, `created_at`.

### Triggers y RPCs:
1. `trg_prohibir_modificacion_abonos`: Inmutabilidad financiera (rechaza `UPDATE` o `DELETE`).
2. `trg_sincronizar_saldo_cliente_por_abono`: Resta el abono del saldo del cliente.
3. `trg_sincronizar_saldo_cliente_por_venta`: Suma la venta a crédito al saldo del cliente.
4. `public.registrar_abono_deuda(...)`: Función transaccional atómica con bloqueo de fila (`FOR UPDATE`).
