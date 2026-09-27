-- ============================================================
-- Migración 07: Datos Semilla de Prueba (Seed Data)
-- Tienda de Barrio y Licorería Familiar
-- Tenant por defecto: 00000000-0000-0000-0000-000000000000
-- ============================================================

-- 1. Insertar Productos de Prueba
-- Casos cubiertos:
-- A) Granel/Fraccionables (Pollo, Queso Criollo)
-- B) Venta Dual (Cigarrillos sueltos, Papel higiénico suelto)
-- C) Desempaque Mayorista Caja -> Botella (Cerveza Paceña, Aceite Fino)
-- D) Reposición y Stock Bajo (Coca Cola, Arroz)

-- Primero insertamos los productos unidad/hijos para que puedan ser referenciados
INSERT INTO public.productos (
    id,
    tenant_id,
    codigo_barras,
    nombre,
    descripcion,
    tipo_unidad,
    stock_actual,
    stock_minimo,
    costo_mayorista,
    precio_venta,
    tipo_empaque,
    unidades_por_empaque,
    costo_por_empaque,
    permite_venta_suelta,
    nombre_unidad_suelta,
    unidades_en_empaque_venta,
    precio_venta_suelta,
    producto_hijo_id,
    estado_activo
) VALUES 
-- 1. Botella Suelta Cerveza Paceña 710ml (Hijo para desempaque)
(
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    '777123400001',
    'Cerveza Paceña Pilsener 710ml (Botella)',
    'Cerveza tradicional botella retornable',
    'UNIDAD',
    6.000,
    12.000,
    10.50,
    14.00,
    'UNIDAD',
    1.0,
    10.50,
    false,
    'unidad',
    1.0,
    0.00,
    NULL,
    true
),
-- 2. Botella Suelta Aceite Fino 1L (Hijo para desempaque)
(
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    '777123400003',
    'Aceite Fino 1 Litro',
    'Aceite vegetal 100% puro',
    'UNIDAD',
    4.000,
    12.000,
    9.50,
    12.00,
    'UNIDAD',
    1.0,
    9.50,
    false,
    'unidad',
    1.0,
    0.00,
    NULL,
    true
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    stock_actual = EXCLUDED.stock_actual,
    precio_venta = EXCLUDED.precio_venta,
    stock_minimo = EXCLUDED.stock_minimo;

-- Luego insertamos las Cajas Padre (que referencian a los hijos) y el resto de productos
INSERT INTO public.productos (
    id,
    tenant_id,
    codigo_barras,
    nombre,
    descripcion,
    tipo_unidad,
    stock_actual,
    stock_minimo,
    costo_mayorista,
    precio_venta,
    tipo_empaque,
    unidades_por_empaque,
    costo_por_empaque,
    permite_venta_suelta,
    nombre_unidad_suelta,
    unidades_en_empaque_venta,
    precio_venta_suelta,
    producto_hijo_id,
    estado_activo
) VALUES 
-- 3. Caja de Cerveza Paceña 710ml (Padre para desempaque en 12 botellas)
(
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    '777123400002',
    'Caja Cerveza Paceña 710ml (x12)',
    'Caja plástica de 12 botellas retornables',
    'UNIDAD',
    4.000,
    2.000,
    126.00,
    160.00,
    'CAJA',
    12.0,
    126.00,
    false,
    'unidad',
    1.0,
    0.00,
    'a0000000-0000-0000-0000-000000000001',
    true
),
-- 4. Caja Aceite Fino 1L (Padre para desempaque en 12 botellas)
(
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000000',
    '777123400004',
    'Caja Aceite Fino 1L (x12)',
    'Caja sellada de fábrica con 12 botellas',
    'UNIDAD',
    3.000,
    2.000,
    110.00,
    140.00,
    'CAJA',
    12.0,
    110.00,
    false,
    'unidad',
    1.0,
    0.00,
    'a0000000-0000-0000-0000-000000000003',
    true
),
-- 5. Pollo Sofía Entero (Granel / Fraccionable)
(
    'a0000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000000',
    '777123400005',
    'Pollo Fresco Sofía (Kg)',
    'Pollo eviscerado fresco por kilo',
    'FRACCIONABLE',
    25.500,
    10.000,
    14.20,
    17.50,
    'KILO',
    1.0,
    14.20,
    false,
    'kilo',
    1.0,
    0.00,
    NULL,
    true
),
-- 6. Queso Criollo Chaqueño (Granel / Fraccionable)
(
    'a0000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000000',
    '777123400006',
    'Queso Criollo Chaqueño (Kg)',
    'Queso criollo artesanal de campo',
    'FRACCIONABLE',
    14.250,
    5.000,
    26.00,
    32.00,
    'KILO',
    1.0,
    26.00,
    false,
    'kilo',
    1.0,
    0.00,
    NULL,
    true
),
-- 7. Cigarrillos Derby Rojo 20s (Venta Dual: Cajetilla Bs. 15 / Suelto Bs. 1.00)
(
    'a0000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000000',
    '777123400007',
    'Cigarrillos Derby Rojo 20s (Cajetilla)',
    'Cajetilla con 20 cigarrillos',
    'UNIDAD',
    10.000,
    5.000,
    12.00,
    15.00,
    'PAQUETE',
    10.0,
    120.00,
    true,
    'cigarrillo',
    20.0,
    1.00,
    NULL,
    true
),
-- 8. Papel Higiénico Scott RindeMax (Venta Dual: Paquete 4 rollos Bs. 12 / Suelto Bs. 3.50)
(
    'a0000000-0000-0000-0000-000000000008',
    '00000000-0000-0000-0000-000000000000',
    '777123400008',
    'Papel Higiénico Scott Paquete (x4)',
    'Paquete de 4 rollos doble hoja',
    'UNIDAD',
    8.000,
    4.000,
    9.50,
    12.00,
    'FARDO',
    6.0,
    55.00,
    true,
    'rollo',
    4.0,
    3.50,
    NULL,
    true
),
-- 9. Coca Cola 2 Litros Retornable (STOCK BAJO para probar Reposición y WhatsApp)
(
    'a0000000-0000-0000-0000-000000000009',
    '00000000-0000-0000-0000-000000000000',
    '777123400009',
    'Coca Cola 2L Retornable',
    'Gaseosa Coca Cola botella retornable',
    'UNIDAD',
    2.000, -- Stock actual bajo
    12.000, -- Stock mínimo
    8.50,
    11.00,
    'PAQUETE',
    6.0,
    51.00,
    false,
    'unidad',
    1.0,
    0.00,
    NULL,
    true
),
-- 10. Arroz Grano de Oro 1kg (STOCK BAJO para probar Reposición de Fardos)
(
    'a0000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000010',
    '777123400010',
    'Arroz Grano de Oro 1kg',
    'Bolsa de arroz seleccionado grado 1',
    'UNIDAD',
    3.000, -- Stock actual bajo
    20.000, -- Stock mínimo
    6.80,
    8.50,
    'FARDO',
    10.0,
    68.00,
    false,
    'unidad',
    1.0,
    0.00,
    NULL,
    true
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    tipo_unidad = EXCLUDED.tipo_unidad,
    stock_actual = EXCLUDED.stock_actual,
    stock_minimo = EXCLUDED.stock_minimo,
    costo_mayorista = EXCLUDED.costo_mayorista,
    precio_venta = EXCLUDED.precio_venta,
    tipo_empaque = EXCLUDED.tipo_empaque,
    unidades_por_empaque = EXCLUDED.unidades_por_empaque,
    costo_por_empaque = EXCLUDED.costo_por_empaque,
    permite_venta_suelta = EXCLUDED.permite_venta_suelta,
    nombre_unidad_suelta = EXCLUDED.nombre_unidad_suelta,
    unidades_en_empaque_venta = EXCLUDED.unidades_en_empaque_venta,
    precio_venta_suelta = EXCLUDED.precio_venta_suelta,
    producto_hijo_id = EXCLUDED.producto_hijo_id,
    estado_activo = true;

-- 2. Insertar Clientes / Vecinos de Prueba para Fiados
INSERT INTO public.clientes (
    id,
    tenant_id,
    nombre,
    telefono,
    limite_credito,
    saldo_actual,
    notas,
    activo
) VALUES 
-- Don Carlos: con deuda moderada (semáforo amarillo: 45 / 100)
(
    'c0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'Don Carlos Gutiérrez',
    '71234567',
    100.00,
    45.50,
    'Vecino de la esquina de la plaza. Paga siempre los sábados.',
    true
),
-- Doña Martha: sin deuda (semáforo verde: 0 / 150)
(
    'c0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'Doña Martha Flores',
    '79876543',
    150.00,
    0.00,
    'Profesora jubilada. Muy buena pagadora.',
    true
),
-- Juan Pérez: deuda con límite casi excedido (semáforo rojo: 95 / 100)
(
    'c0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'Juan Pérez (Taller)',
    '76543210',
    100.00,
    95.00,
    'Mecánico frente a la tienda. Cobrar antes de volver a fiar.',
    true
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    telefono = EXCLUDED.telefono,
    limite_credito = EXCLUDED.limite_credito,
    saldo_actual = EXCLUDED.saldo_actual,
    notas = EXCLUDED.notas,
    activo = true;
