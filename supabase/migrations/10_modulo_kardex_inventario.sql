-- ============================================================
-- Migración 10: Módulo de Kardex y Auditoría Completa de Inventario
-- (Soporte para Ventas, Mermas, Desempaques, Transición de Stock y Trazabilidad)
-- ============================================================

-- 1. Ampliar tipos de movimientos permitidos en movimientos_inventario
ALTER TABLE public.movimientos_inventario 
DROP CONSTRAINT IF EXISTS movimientos_inventario_tipo_movimiento_check;

ALTER TABLE public.movimientos_inventario 
ADD CONSTRAINT movimientos_inventario_tipo_movimiento_check CHECK (
    tipo_movimiento IN (
        'VENTA',               -- Salida por venta en punto de venta
        'ENTRADA_COMPRA',      -- Ingreso por compra a proveedor
        'MERMA_ROTURA',        -- Botella quebrada o dañada en tienda
        'MERMA_VENCIMIENTO',   -- Producto vencido
        'MERMA_DETERIORO',     -- Empaque aplastado o defectuoso
        'AJUSTE_POSITIVO',     -- Conteo físico sobrante
        'AJUSTE_NEGATIVO',     -- Conteo físico faltante
        'AJUSTE_MANUAL',       -- Ajuste manual desde edición de catálogo
        'DESEMPAQUE_SALIDA',   -- Resta de cajas mayoristas
        'DESEMPAQUE_ENTRADA'   -- Suma de unidades sueltas
    )
);

-- 2. Agregar columnas para registrar el stock antes y después (Kardex tradicional)
ALTER TABLE public.movimientos_inventario 
ADD COLUMN IF NOT EXISTS stock_anterior NUMERIC(12, 3) NULL,
ADD COLUMN IF NOT EXISTS stock_posterior NUMERIC(12, 3) NULL,
ADD COLUMN IF NOT EXISTS usuario_id UUID NULL;

-- 3. Índices compuestos para filtrado rápido por fecha, producto y tipo
CREATE INDEX IF NOT EXISTS idx_kardex_tenant_producto_fecha 
ON public.movimientos_inventario(tenant_id, producto_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_kardex_tenant_tipo_fecha 
ON public.movimientos_inventario(tenant_id, tipo_movimiento, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_kardex_tenant_fecha 
ON public.movimientos_inventario(tenant_id, created_at DESC);

-- 4. Actualizar función RPC registrar_merma para guardar stock_anterior y stock_posterior
CREATE OR REPLACE FUNCTION public.registrar_merma(
    p_producto_id UUID,
    p_cantidad NUMERIC,
    p_tipo_merma VARCHAR,
    p_motivo TEXT,
    p_tenant_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_stock_actual NUMERIC;
    v_costo_unitario NUMERIC;
    v_costo_total NUMERIC;
    v_nuevo_stock NUMERIC;
    v_movimiento_id UUID := gen_random_uuid();
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de merma debe ser mayor a 0';
    END IF;

    IF p_tipo_merma NOT IN ('MERMA_ROTURA', 'MERMA_VENCIMIENTO', 'MERMA_DETERIORO') THEN
        RAISE EXCEPTION 'Tipo de merma inválido: %. Debe ser MERMA_ROTURA, MERMA_VENCIMIENTO o MERMA_DETERIORO', p_tipo_merma;
    END IF;

    -- Bloqueo transaccional
    SELECT stock_actual, costo_mayorista
    INTO v_stock_actual, v_costo_unitario
    FROM public.productos
    WHERE id = p_producto_id AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado en el tenant especificado';
    END IF;

    v_costo_total := v_costo_unitario * p_cantidad;
    v_nuevo_stock := GREATEST(0.00, v_stock_actual - p_cantidad);

    -- 1. Descontar stock del producto
    UPDATE public.productos
    SET stock_actual = v_nuevo_stock,
        updated_at = NOW()
    WHERE id = p_producto_id;

    -- 2. Registrar movimiento inmutable con stock_anterior y stock_posterior
    INSERT INTO public.movimientos_inventario (
        id, tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id,
        stock_anterior, stock_posterior
    ) VALUES (
        v_movimiento_id, p_tenant_id, p_producto_id, p_tipo_merma, p_cantidad,
        v_costo_unitario, v_costo_total, COALESCE(p_motivo, 'Registro de merma de inventario'), NULL,
        v_stock_actual, v_nuevo_stock
    );

    RETURN jsonb_build_object(
        'success', true,
        'cantidad_merma', p_cantidad,
        'costo_perdida', v_costo_total,
        'stock_anterior', v_stock_actual,
        'nuevo_stock', v_nuevo_stock
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Actualizar función RPC desempaquetar_producto para registrar stock_anterior y stock_posterior
CREATE OR REPLACE FUNCTION public.desempaquetar_producto(
    p_caja_id UUID,
    p_unidades_id UUID,
    p_cantidad_cajas NUMERIC,
    p_tenant_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_stock_caja NUMERIC;
    v_costo_caja NUMERIC;
    v_factor_unidades NUMERIC;
    v_nuevo_stock_caja NUMERIC;
    v_stock_unidades NUMERIC;
    v_nuevo_stock_unidades NUMERIC;
    v_costo_unidad NUMERIC;
    v_unidades_a_sumar NUMERIC;
    v_ref_id UUID := gen_random_uuid();
BEGIN
    IF p_cantidad_cajas <= 0 THEN
        RAISE EXCEPTION 'La cantidad de cajas a desempaquetar debe ser mayor a 0';
    END IF;

    -- Bloquear y leer caja
    SELECT stock_actual, costo_mayorista, unidades_por_empaque
    INTO v_stock_caja, v_costo_caja, v_factor_unidades
    FROM public.productos
    WHERE id = p_caja_id AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto caja/pack no encontrado';
    END IF;

    IF v_stock_caja < p_cantidad_cajas THEN
        RAISE EXCEPTION 'Stock insuficiente de cajas para desempaquetar. Stock actual: %, Solicitado: %',
            v_stock_caja, p_cantidad_cajas;
    END IF;

    -- Bloquear y leer unidades hijas
    SELECT stock_actual, costo_mayorista
    INTO v_stock_unidades, v_costo_unidad
    FROM public.productos
    WHERE id = p_unidades_id AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto unidad destino no encontrado';
    END IF;

    v_unidades_a_sumar := p_cantidad_cajas * v_factor_unidades;
    v_nuevo_stock_caja := v_stock_caja - p_cantidad_cajas;
    v_nuevo_stock_unidades := v_stock_unidades + v_unidades_a_sumar;

    -- Actualizar stock de cajas
    UPDATE public.productos
    SET stock_actual = v_nuevo_stock_caja,
        updated_at = NOW()
    WHERE id = p_caja_id;

    -- Actualizar stock de unidades sueltas
    UPDATE public.productos
    SET stock_actual = v_nuevo_stock_unidades,
        updated_at = NOW()
    WHERE id = p_unidades_id;

    -- Auditoría salida de cajas
    INSERT INTO public.movimientos_inventario (
        tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id,
        stock_anterior, stock_posterior
    ) VALUES (
        p_tenant_id, p_caja_id, 'DESEMPAQUE_SALIDA', p_cantidad_cajas,
        v_costo_caja, (v_costo_caja * p_cantidad_cajas),
        COALESCE(p_motivo, 'Desempaque a botellas sueltas'), v_ref_id,
        v_stock_caja, v_nuevo_stock_caja
    );

    -- Auditoría entrada de unidades sueltas
    INSERT INTO public.movimientos_inventario (
        tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id,
        stock_anterior, stock_posterior
    ) VALUES (
        p_tenant_id, p_unidades_id, 'DESEMPAQUE_ENTRADA', v_unidades_a_sumar,
        v_costo_unidad, (v_costo_unidad * v_unidades_a_sumar),
        COALESCE(p_motivo, 'Ingreso por desempaque de caja mayorista'), v_ref_id,
        v_stock_unidades, v_nuevo_stock_unidades
    );

    RETURN jsonb_build_object(
        'success', true,
        'cantidad_cajas', p_cantidad_cajas,
        'unidades_sumadas', v_unidades_a_sumar,
        'nuevo_stock_caja', v_nuevo_stock_caja,
        'nuevo_stock_unidades', v_nuevo_stock_unidades
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6. Retro-poblar ventas históricas existentes en movimientos_inventario
-- Si existían ventas realizadas antes de este módulo, se importan automáticamente al Kardex
-- ============================================================
INSERT INTO public.movimientos_inventario (
    tenant_id,
    producto_id,
    tipo_movimiento,
    cantidad,
    costo_unitario,
    costo_total,
    motivo,
    referencia_id,
    created_at
)
SELECT 
    v.tenant_id,
    dv.producto_id,
    'VENTA',
    dv.cantidad,
    dv.costo_unitario,
    (dv.costo_unitario * dv.cantidad),
    'Venta mostrador (Ticket #' || SUBSTRING(v.id::TEXT, 1, 8) || ')',
    v.id,
    v.fecha_venta
FROM public.detalle_ventas dv
JOIN public.ventas v ON v.id = dv.venta_id
JOIN public.productos p ON p.id = dv.producto_id
WHERE NOT EXISTS (
    SELECT 1 FROM public.movimientos_inventario mi 
    WHERE mi.referencia_id = v.id AND mi.producto_id = dv.producto_id
);

