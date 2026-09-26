# Sistema POS & ERP Ligero para Tienda de Barrio y Licorería Familiar

Sistema integral de Punto de Venta (POS) y gestión operativa (ERP ligero) diseñado específicamente para tiendas de barrio y licorerías familiares. El sistema está optimizado para personas mayores sin destreza tecnológica previa, garantizando accesibilidad extrema, ejecución fluida en celulares de gama baja, inmutabilidad financiera para auditoría y automatización contable.

---

## 🎯 1. Visión y Accesibilidad
- **Usuario Principal**: Persona mayor, dueña de negocio familiar, sin conocimientos técnicos avanzados.
- **Accesibilidad Extrema**:
  - Botones táctiles grandes (touch targets ≥ 56dp) para fácil pulsación.
  - Alto contraste y tipografía nítida y legible.
  - Tolerancia a errores ortográficos mediante **Fuzzy Search**.
  - Sin animaciones complejas ni transiciones pesadas para no saturar dispositivos móviles de gama baja.
  - Cálculos financieros 100% automatizados (cero operaciones manuales para el usuario).

---

## 🏗️ 2. Arquitectura de Software
- **Modelo de Despliegue**: Monolito sustentado en Backend-as-a-Service (**Supabase**). Cero microservicios innecesarios.
- **Patrón Interno**: **Feature-First** (código organizado por dominios de negocio, no por tipo de archivo).
- **Separación de Capas**:
  - **UI (Presentación)**: Pantallas y componentes visuales declarativos (ConsumerWidget).
  - **State (Controladores)**: Notifiers con Riverpod para lógica de negocio, cálculos y estados temporales.
  - **Data (Repositorios)**: Consultas SQL en Supabase, persistencia local y mapeo de modelos.

---

## 💻 3. Stack Tecnológico
| Capa / Función | Tecnología Elegida | Justificación |
| :--- | :--- | :--- |
| **Frontend / Móvil** | **Flutter (Dart)** | Alto rendimiento multiplataforma, control total de renderizado UI |
| **Gestión de Estado** | **Riverpod** | Reactividad segura, fuertemente tipada y testeable |
| **Base de Datos Local** | **Isar Database** | Soporte offline-first, velocidad ACID y optimización en móvil |
| **Backend & Base de Datos** | **Supabase (PostgreSQL)** | RLS (seguridad por fila), autenticación integrada, triggers y realtime |
| **Inteligencia Artificial** | **OpenAI Whisper + GPT-4o-mini** | Reconocimiento de voz (STT) y procesamiento de lenguaje natural en la nube |

---

## ⚖️ 4. Reglas de Negocio Estrictas y Auditoría
1. **Inmutabilidad Financiera**:
   - Las ventas confirmadas y abonos de fiados **jamás se modifican ni se eliminan** (`NO UPDATE`, `NO DELETE`).
   - Las correcciones o devoluciones se realizan únicamente mediante **transacciones inversas documentadas** (anulaciones / notas de crédito) con referencia al registro original.
2. **Prohibición de Borrado Físico (Soft Delete)**:
   - Inventario, productos, categorías y clientes utilizan borrado lógico (`estado_activo = false`).
   - Mantiene intacta la trazabilidad histórica de los reportes pasados.
3. **Aislamiento Multi-Tenant**:
   - Cada tabla y consulta filtra estrictamente por `tenant_id`.
   - Supabase implementa **Row Level Security (RLS)** para aislar la información entre diferentes sucursales o familiares.

---

## 📦 5. Módulos y Funcionalidades Principales
1. **Gestión de Inventario y Catálogo Mixto**:
   - Familias y categorías (licores, abarrotes, limpieza).
   - **Modelado de Empaques Mayoristas**: Cajas, paquetes six-pack, fardos/jabas, tiras, bolsas y kilos.
   - **Venta Dual al Detalle**: Soporte para vender empaques enteros (ej. cajetilla) o unidades sueltas (ej. cigarrillos individuales) con descuento fraccional de inventario.
   - **Venta a Granel y Balanza**: Modal táctil con recuadro directo de dinero, fracciones rápidas (1/4, 1/2, 3/4, 1 kg) y teclado desplegable para balanza física.
   - **Lista de Reposición Inteligente**: Cálculo automático de compras sugeridas en empaques cerrados y kilos enteros para granel, con generador de pedidos directos a **WhatsApp**.
   - Alertas preventivas de caducidad y registro de **Bajas por Mermas** (roturas, vencimientos).
   - Búsqueda aproximada (**Fuzzy Search**) y lectura veloz por código de barras.
2. **Punto de Venta (POS) & Registro Rápido**:
   - **Ticket en Espera**: Carrito pausable a prueba de interrupciones (sin descuento de stock hasta el cobro manual).
   - Entradas multicanal: escáner de barras, fuzzy search y cuadrícula con íconos vectoriales para celulares de gama baja.
   - Fraccionamiento de pagos mixtos y soporte para **Cashback** (retiro de efectivo contra pago QR excedente).
   - Continuidad operativa offline con sincronización bidireccional (Fase 2).
3. **Módulo Financiero Automático**:
   - **Cierre Rápido con Fondo Fijo**: Conteo enfocado en billetes mayores con resultado visual estilo **semáforo (verde/rojo)**.
   - Estado de resultados en tiempo real con **Utilidad Neta Real** (`Ventas - Costo Mayorista - Gastos Fijos`).
   - Envío de tickets digitales por **WhatsApp** y reporte mensual en PDF con ranking de rentabilidad.
4. **Cuentas por Cobrar (Deudores / Fiados)**:
   - Perfiles de deudores con límites de crédito individuales con bloqueo preventivo.
   - Historial inmutable y rastreable de deudas y abonos vinculados a cada ticket.
5. **Inteligencia Artificial Híbrida**:
   - Asistente de voz en la nube (**Whisper + GPT-4o-mini**) para dictado de ventas al carrito.
   - Motor de predicción de demanda estacional (festividades, fines de semana).
   - Alertas de optimización de margen ante subidas de costos de distribuidores.
6. **Seguridad y Control Multi-Tienda**:
   - Aislamiento **Multi-Tenant** estricto por tienda/sucursal en Supabase (RLS).
   - Roles y permisos (RBAC): Administrador (dueño) vs. Cajero (solo cobro y caja).
   - Auditoría interna inmutable de cancelaciones y ajustes.

---

## 🗺️ 6. Fases de Desarrollo
- **Fase 1 (Actual)**: MVP 100% online en Supabase (POS, Inventario, Deudores, Finanzas básicas).
- **Fase 2**: Modo Offline con Isar Database y colas de sincronización en segundo plano.
- **Fase 3**: Multi-Tenant federado y análisis predictivo de compras/stock con IA.

---

## 🧠 Memoria Persistente (Engram)
El contexto y especificaciones completas de este proyecto están sincronizados en el almacén de memoria **Engram** bajo el proyecto `si-tienda-barrio`:
- `#10 architecture/overview`
- `#11 architecture/stack-and-patterns`
- `#12 architecture/business-rules-audit`
- `#13 architecture/modules-specs`
- `#14 architecture/pos-financial-flows`
- `#15 architecture/roadmap-phases`
- `#16 architecture/master-context`
- `#17 convention/guardian-mode`
- `#18 spec/functional-requirements`
- `#19 architecture/ai-hybrid-specs`
- `#20 architecture/security-rbac-audit`
- `#21 docs/contexto_venta_fraccionada_empaques.md` (Venta Fraccionada, Venta Dual y Empaques Mayoristas)
