-- ============================================================
-- Migración 15: Limpieza Total y Carga de Nuevos Datos de Prueba
-- Restaura la base de datos a un estado fresco, limpio y realista
-- Tenant: 00000000-0000-0000-0000-000000000000
-- ============================================================

-- 1. DESACTIVAR TEMPORALMENTE TRIGGERS DE SEGURIDAD PARA LIMPIEZA
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_prohibir_modificacion_abonos'
    ) THEN
        ALTER TABLE public.abonos_deuda DISABLE TRIGGER trg_prohibir_modificacion_abonos;
    END IF;
END $$;

-- 2. VACIAR TODAS LAS TABLAS DE TRANSACCIONES Y CATÁLOGO
TRUNCATE TABLE 
    public.detalle_ventas,
    public.ventas,
    public.detalle_compras,
    public.compras,
    public.movimientos_inventario,
    public.movimientos_caja,
    public.cajas_turnos,
    public.abonos_deuda,
    public.clientes,
    public.productos,
    public.categorias,
    public.proveedores
CASCADE;

-- REACTIVAR TRIGGER DE INMUTABILIDAD EN ABONOS
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_prohibir_modificacion_abonos'
    ) THEN
        ALTER TABLE public.abonos_deuda ENABLE TRIGGER trg_prohibir_modificacion_abonos;
    END IF;
END $$;

-- ============================================================
-- 3. INSERTAR PROVEEDORES REALISTAS DE BOLIVIA
-- (Prefijo UUID: 10000000...)
-- ============================================================
INSERT INTO public.proveedores (id, tenant_id, nombre_empresa, nombre_contacto, telefono, dias_visita, activo) VALUES
('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'Cervecería Boliviana Nacional - CBN', 'Carlos Preventista', '77712345', 'Martes y Viernes', true),
('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'Embol S.A. (Coca-Cola / Vital)', 'Marcelo Pedidos', '76543210', 'Lunes y Jueves', true),
('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'PIL Andina S.A. (Lácteos)', 'Dra. Patricia', '71234567', 'Miércoles', true),
('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'Distribuidora Yungas & Chapare (Coca)', 'Doña Martha', '78901234', 'Sábados', true),
('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'Distribuidora La Oriental (Abarrotes y Aceites)', 'Jorge Camión', '70123456', 'Martes', true),
('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'Tabacos y Golosinas El Alto', 'Roberto Mayorista', '73456789', 'Miércoles', true);

-- ============================================================
-- 4. INSERTAR CATEGORÍAS Y SUBCATEGORÍAS EN ÁRBOL
-- ============================================================
-- Categorías Principales (Prefijo UUID: 20000000...)
INSERT INTO public.categorias (id, tenant_id, nombre, icono, orden) VALUES
('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'Cervezas', '🍺', 1),
('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'Gaseosas y Aguas', '🥤', 2),
('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'Coca y Derivados', '🌿', 3),
('20000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'Lácteos y Embutidos', '🥛', 4),
('20000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'Golosinas y Snacks', '🍪', 5),
('20000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'Cigarrillos', '🚬', 6),
('20000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000000', 'Abarrotes y Alimentos', '🍞', 7),
('20000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000000', 'Limpieza y Aseo', '🧼', 8);

-- Subcategorías (Prefijo UUID: 30000000...)
INSERT INTO public.categorias (id, tenant_id, nombre, parent_id, orden) VALUES
-- Cervezas (hijos de 20000000-0000-0000-0000-000000000001)
('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'Huari', '20000000-0000-0000-0000-000000000001', 1),
('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'Paceña', '20000000-0000-0000-0000-000000000001', 2),
('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Corona', '20000000-0000-0000-0000-000000000001', 3),
('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'Taquiña', '20000000-0000-0000-0000-000000000001', 4),
('30000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '710cc', '20000000-0000-0000-0000-000000000001', 5),
('30000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'Lata 354cc', '20000000-0000-0000-0000-000000000001', 6),

-- Gaseosas (hijos de 20000000-0000-0000-0000-000000000002)
('30000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000000', 'Coca-Cola', '20000000-0000-0000-0000-000000000002', 1),
('30000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000000', 'Pepsi', '20000000-0000-0000-0000-000000000002', 2),
('30000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000000', '2 Litros', '20000000-0000-0000-0000-000000000002', 3),
('30000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000000', 'Personal 500ml', '20000000-0000-0000-0000-000000000002', 4),

-- Coca y Derivados (hijos de 20000000-0000-0000-0000-000000000003)
('30000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000000', 'Hoja Seleccionada', '20000000-0000-0000-0000-000000000003', 1),
('30000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000000', 'Machucada Menta', '20000000-0000-0000-0000-000000000003', 2),
('30000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000000', 'Machucada Bico', '20000000-0000-0000-0000-000000000003', 3),
('30000000-0000-0000-0000-000000000023', '00000000-0000-0000-0000-000000000000', 'Machucada Café', '20000000-0000-0000-0000-000000000003', 4),

-- Lácteos (hijos de 20000000-0000-0000-0000-000000000004)
('30000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000000', 'Leche Pil', '20000000-0000-0000-0000-000000000004', 1),
('30000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000000', 'Queso Criollo', '20000000-0000-0000-0000-000000000004', 2),

-- Golosinas (hijos de 20000000-0000-0000-0000-000000000005)
('30000000-0000-0000-0000-000000000040', '00000000-0000-0000-0000-000000000000', 'Chicles', '20000000-0000-0000-0000-000000000005', 1),
('30000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000000', 'Chocolates', '20000000-0000-0000-0000-000000000005', 2),

-- Cigarrillos (hijos de 20000000-0000-0000-0000-000000000006)
('30000000-0000-0000-0000-000000000050', '00000000-0000-0000-0000-000000000000', 'Camel', '20000000-0000-0000-0000-000000000006', 1),
('30000000-0000-0000-0000-000000000051', '00000000-0000-0000-0000-000000000000', 'Derby', '20000000-0000-0000-0000-000000000006', 2),

-- Abarrotes (hijos de 20000000-0000-0000-0000-000000000007)
('30000000-0000-0000-0000-000000000060', '00000000-0000-0000-0000-000000000000', 'Aceite Fino', '20000000-0000-0000-0000-000000000007', 1),
('30000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000000', 'Arroz y Fideo', '20000000-0000-0000-0000-000000000007', 2);

-- ============================================================
-- 5. INSERTAR PRODUCTOS CUBRIENDO LOS 4 MODOS DE VENTA
-- (Prefijo UUID: 40000000...)
-- ============================================================

-- Primero insertamos los productos hijos de venta suelta para que puedan ser referenciados
INSERT INTO public.productos (
    id, tenant_id, codigo_barras, nombre, descripcion,
    tipo_unidad, stock_actual, stock_minimo, costo_mayorista, precio_venta,
    tipo_empaque, unidades_por_empaque, costo_por_empaque,
    permite_venta_suelta, nombre_unidad_suelta, unidades_en_empaque_venta, precio_venta_suelta,
    proveedor_id, categoria, subcategoria, estado_activo
) VALUES
-- MODO 2 (Hijo de desempaque): Botella Huari 710ml en mostrador (Stock bajo intencional para ver reposición)
(
    '40000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000000',
    '77710001', 'Cerveza Huari Tradicional 710ml', 'Botella de vidrio retornable',
    'UNIDAD', 4.000, 12.000, 11.00, 15.00,
    'UNIDAD', 1.0, 11.00,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000001', 'Cervezas', 'Huari', true
),
-- MODO 2 (Hijo de desempaque): Botella Paceña 710ml en mostrador
(
    '40000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000000',
    '77710002', 'Cerveza Paceña Pilsener 710ml', 'Botella retornable tradicional',
    'UNIDAD', 8.000, 12.000, 10.50, 14.00,
    'UNIDAD', 1.0, 10.50,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000001', 'Cervezas', 'Paceña', true
),
-- MODO 2 (Hijo de desempaque): Aceite Fino 1 Litro en mostrador (Stock bajo)
(
    '40000000-0000-0000-0000-000000000016', '00000000-0000-0000-0000-000000000000',
    '77710003', 'Aceite Fino 1 Litro', 'Aceite vegetal 100% puro',
    'UNIDAD', 3.000, 12.000, 9.50, 12.00,
    'UNIDAD', 1.0, 9.50,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000005', 'Abarrotes y Alimentos', 'Aceite Fino', true
);

-- Insertar Cajas Padre y el resto de productos de los 4 modos
INSERT INTO public.productos (
    id, tenant_id, codigo_barras, nombre, descripcion,
    tipo_unidad, stock_actual, stock_minimo, costo_mayorista, precio_venta,
    tipo_empaque, unidades_por_empaque, costo_por_empaque, precio_empaque_mayorista,
    producto_hijo_id,
    permite_venta_suelta, nombre_unidad_suelta, unidades_en_empaque_venta, precio_venta_suelta,
    proveedor_id, categoria, subcategoria, estado_activo
) VALUES
-- MODO 2 (Caja Padre): Caja Huari 710ml (2 cajas en almacén para cubrir las 4 de mostrador)
(
    '40000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000000',
    '77710011', 'Caja Cerveza Huari 710ml (12 botellas)', 'Caja plástica de 12 unidades',
    'UNIDAD', 2.000, 1.000, 11.00, 15.00,
    'CAJA', 12.0, 132.00, 170.00,
    '40000000-0000-0000-0000-000000000010',
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000001', 'Cervezas', 'Huari', true
),
-- MODO 2 (Caja Padre): Caja Paceña 710ml (3 cajas en almacén)
(
    '40000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000000',
    '77710013', 'Caja Cerveza Paceña 710ml (12 botellas)', 'Caja plástica de 12 unidades',
    'UNIDAD', 3.000, 1.000, 10.50, 14.00,
    'CAJA', 12.0, 126.00, 160.00,
    '40000000-0000-0000-0000-000000000012',
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000001', 'Cervezas', 'Paceña', true
),
-- MODO 2: Fardo Coca-Cola 2L Retornable (Venta por unidad o fardo de 6)
(
    '40000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000000',
    '77710014', 'Coca-Cola 2 Litros Retornable', 'Gaseosa botella de 2 litros familiar',
    'UNIDAD', 18.000, 6.000, 10.00, 13.00,
    'FARDO', 6.0, 60.00, 72.00,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000002', 'Gaseosas y Aguas', '2 Litros', true
),
-- MODO 2: Caja de Chicles Clorets (Se vende por unidad suelta de 2 Bs)
(
    '40000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000000',
    '77710015', 'Chicles Clorets Menta', 'Cajita individual de chicles',
    'UNIDAD', 15.000, 5.000, 1.50, 2.00,
    'CAJA', 20.0, 30.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000006', 'Golosinas y Snacks', 'Chicles', true
),

-- MODO 1 (🏷️ POR UNIDAD / SIMPLE): Coca Machucada Menta
(
    '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
    NULL, 'Coca Machucada Menta (Bolsita)', 'Bolsita lista con sabor mentolado',
    'UNIDAD', 8.000, 3.000, 4.00, 5.00,
    'UNIDAD', 1.0, 4.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000004', 'Coca y Derivados', 'Machucada Menta', true
),
-- MODO 1 (🏷️ POR UNIDAD / SIMPLE): Coca Machucada Bico
(
    '40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
    NULL, 'Coca Machucada Bico (Bolsita)', 'Bolsita machucada con bicarbonato tradicional',
    'UNIDAD', 6.000, 3.000, 4.00, 5.00,
    'UNIDAD', 1.0, 4.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000004', 'Coca y Derivados', 'Machucada Bico', true
),
-- MODO 1 (🏷️ POR UNIDAD / SIMPLE): Producto de prueba de mercado
(
    '40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
    '77710005', 'Alfajor Triple Manjar (Prueba)', 'Comprado suelto para probar venta',
    'UNIDAD', 5.000, 2.000, 3.50, 5.00,
    'UNIDAD', 1.0, 3.50, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000006', 'Golosinas y Snacks', 'Chocolates', true
),
-- MODO 1 (🏷️ POR UNIDAD / SIMPLE): Bolsa de Hielo
(
    '40000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000',
    NULL, 'Bolsa de Hielo Cristal 2kg', 'Hielo en cubos para refrescos y bebidas',
    'UNIDAD', 12.000, 4.000, 5.00, 8.00,
    'UNIDAD', 1.0, 5.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    NULL, 'Gaseosas y Aguas', NULL, true
),

-- MODO 3 (🚬 SUELTO 3 NIVELES): Cigarrillos Camel Box 20
(
    '40000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000000',
    '77720001', 'Cigarrillos Camel Box 20', 'Cajetilla de 20 cigarrillos rubios con filtro',
    'UNIDAD', 6.000, 2.000, 16.00, 22.00,
    'PAQUETE', 10.0, 160.00, NULL,
    NULL,
    true, 'cigarro', 20.0, 1.50,
    '10000000-0000-0000-0000-000000000006', 'Cigarrillos', 'Camel', true
),
-- MODO 3 (🚬 SUELTO 3 NIVELES): Cigarrillos Derby Rojo 20
(
    '40000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000000',
    '77720002', 'Cigarrillos Derby Rojo 20', 'Cajetilla de 20 cigarrillos',
    'UNIDAD', 4.000, 2.000, 12.00, 16.00,
    'PAQUETE', 10.0, 120.00, NULL,
    NULL,
    true, 'cigarro', 20.0, 1.00,
    '10000000-0000-0000-0000-000000000006', 'Cigarrillos', 'Derby', true
),

-- MODO 4 (⚖️ GRANEL / BALANZA): Hoja de Coca por Libra
(
    '40000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000000',
    NULL, 'Hoja de Coca Yungas (Por Libra)', 'Hoja de coca seleccionada para venta en balanza',
    'FRACCIONABLE', 4.500, 2.000, 95.00, 120.00,
    'LIBRA', 1.0, 95.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000004', 'Coca y Derivados', 'Hoja Seleccionada', true
),
-- MODO 4 (⚖️ GRANEL / BALANZA): Queso Criollo Chaqueño por Kilo
(
    '40000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000000',
    NULL, 'Queso Criollo Chaqueño', 'Queso criollo artesanal fresco para pesar',
    'FRACCIONABLE', 6.800, 2.500, 26.00, 34.00,
    'KILO', 1.0, 26.00, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    '10000000-0000-0000-0000-000000000003', 'Lácteos y Embutidos', 'Queso Criollo', true
),
-- MODO 4 (⚖️ GRANEL / BALANZA): Pollo Fresco Sofía por Kilo
(
    '40000000-0000-0000-0000-000000000032', '00000000-0000-0000-0000-000000000000',
    NULL, 'Pollo Fresco Sofía', 'Pollo eviscerado fresco para balanza',
    'FRACCIONABLE', 14.200, 5.000, 14.50, 18.00,
    'KILO', 1.0, 14.50, NULL,
    NULL,
    false, 'unidad', 1.0, 0.00,
    NULL, 'Abarrotes y Alimentos', 'Arroz y Fideo', true
);

-- ============================================================
-- 6. INSERTAR CLIENTES DEUDORES (FIADOS) CON SALDOS REALISTAS
-- (Prefijo UUID: 50000000...)
-- ============================================================
INSERT INTO public.clientes (id, tenant_id, nombre, telefono, limite_credito, saldo_actual, notas) VALUES
('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'Doña Carmen Ortiz', '71122334', 200.00, 45.00, 'Vecina de la casa 14, paga los fines de mes'),
('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'Don Pedro Ramos', '72233445', 350.00, 110.00, 'Mecánico de la esquina'),
('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'Juan Carlos Albañil', '73344556', 150.00, 0.00, 'Cliente puntual, saldo al día');

-- ============================================================
-- 7. REGISTRAR UN TURNO DE CAJA ABIERTO CON SALDO INICIAL
-- (Prefijo UUID: 60000000...)
-- ============================================================
INSERT INTO public.cajas_turnos (
    id, tenant_id, fecha_apertura, monto_inicial,
    total_ventas_efectivo, total_ventas_qr, total_fiados_otorgados,
    monto_esperado_efectivo, estado
) VALUES (
    '60000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    NOW(),
    150.00, -- 150 Bs de cambio inicial
    0.00,
    0.00,
    0.00,
    150.00,
    'ABIERTA'
);

-- ============================================================
-- 8. REGISTRAR KARDEX INICIAL DE LOS PRODUCTOS
-- ============================================================
INSERT INTO public.movimientos_inventario (
    tenant_id, producto_id, tipo_movimiento, cantidad, stock_anterior, stock_posterior, motivo
) VALUES
('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000001', 'AJUSTE_POSITIVO', 8.00, 0.00, 8.00, 'Carga de inventario inicial - Coca Machucada Menta'),
('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000010', 'AJUSTE_POSITIVO', 4.00, 0.00, 4.00, 'Carga de inventario inicial - Huari 710ml mostrador'),
('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000011', 'AJUSTE_POSITIVO', 2.00, 0.00, 2.00, 'Carga de cajas en almacén - Cajas Huari'),
('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000030', 'AJUSTE_POSITIVO', 4.50, 0.00, 4.50, 'Carga de inventario inicial - Coca por Libra'),
('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000020', 'AJUSTE_POSITIVO', 6.00, 0.00, 6.00, 'Carga de inventario inicial - Camel Box');
