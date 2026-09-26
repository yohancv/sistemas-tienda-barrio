-- ============================================================
-- Migración 04: Soporte de Empaques Mayoristas y Venta Fraccionada/Suelta
-- ============================================================
-- Agrega columnas para modelar la presentación de compra mayorista
-- (cajas, paquetes, fardos, jabas, bolsas, tiras, kilos/libras)
-- y la venta dual al detalle (ej. cigarrillos sueltos desde cajetilla).
--
-- Valores DEFAULT retrocompatibles: productos existentes se comportan
-- como unidades sueltas sin empaque mayorista ni venta fraccionada.
-- ============================================================

-- 1. Soporte de empaques mayoristas de compra
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS tipo_empaque VARCHAR(50) NOT NULL DEFAULT 'UNIDAD'
    CHECK (tipo_empaque IN ('UNIDAD', 'CAJA', 'PAQUETE', 'FARDO', 'BOLSA', 'TIRA', 'KILO', 'LIBRA')),
ADD COLUMN IF NOT EXISTS unidades_por_empaque NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS costo_por_empaque NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 2. Soporte de venta dual al detalle (ej. cigarrillos sueltos, pastillas individuales)
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS permite_venta_suelta BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS nombre_unidad_suelta VARCHAR(50) NULL DEFAULT 'unidad',
ADD COLUMN IF NOT EXISTS unidades_en_empaque_venta NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS precio_venta_suelta NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 3. Comentarios documentales para el equipo
COMMENT ON COLUMN public.productos.tipo_empaque IS
    'Presentación mayorista: UNIDAD (suelto), CAJA, PAQUETE, FARDO, BOLSA, TIRA, KILO, LIBRA';
COMMENT ON COLUMN public.productos.unidades_por_empaque IS
    'Cuántas unidades de venta contiene un empaque cerrado (ej. 12 botellas por caja, 6 sodas por paquete)';
COMMENT ON COLUMN public.productos.costo_por_empaque IS
    'Precio que cobra el distribuidor por el empaque cerrado (Bs.)';
COMMENT ON COLUMN public.productos.permite_venta_suelta IS
    'Si true, el producto se puede vender al detalle/suelto (ej. cigarrillos individuales desde cajetilla)';
COMMENT ON COLUMN public.productos.nombre_unidad_suelta IS
    'Nombre de la unidad suelta para mostrar al usuario (ej. cigarrillo, pastilla, rollo)';
COMMENT ON COLUMN public.productos.unidades_en_empaque_venta IS
    'Cuántas unidades sueltas contiene el empaque de venta (ej. 20 cigarrillos en cajetilla)';
COMMENT ON COLUMN public.productos.precio_venta_suelta IS
    'Precio de venta al público por cada unidad suelta (ej. Bs. 1.00 por cigarrillo)';
