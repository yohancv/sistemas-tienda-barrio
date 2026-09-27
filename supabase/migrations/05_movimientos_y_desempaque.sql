-- ============================================================
-- Migración 05: Movimientos de Inventario Inmutables,
-- Desempaque Mayorista Atómico y Registro de Mermas con Costo Financiero
-- ============================================================

-- 1. Enlace opcional en productos para vincular Caja -> Botella/Unidad Suelta
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS producto_hijo_id UUID NULL REFERENCES public.productos(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.productos.producto_hijo_id IS
    'ID del producto unidad que se genera al desempaquetar esta caja/pack (ej. Botella de Huari)';

-- 2. Tabla Inmutable de Movimientos de Inventario
CREATE TABLE IF NOT EXISTS public.movimientos_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    tipo_movimiento VARCHAR(40) NOT NULL CHECK (
        tipo_movimiento IN (
            'DESEMPAQUE_SALIDA',   -- Resta cajas
            'DESEMPAQUE_ENTRADA',  -- Suma unidades sueltas
            'MERMA_ROTURA',        -- Botella quebrada o dañada
            'MERMA_VENCIMIENTO',   -- Producto vencido
            'MERMA_DETERIORO',     -- Empaque aplastado o defectuoso
            'AJUSTE_POSITIVO',     -- Conteo sobrante
            'AJUSTE_NEGATIVO'      -- Conteo faltante
        )
    ),
    cantidad NUMERIC(12, 3) NOT NULL CHECK (cantidad > 0),
    costo_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    costo_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    motivo TEXT NULL,
    referencia_id UUID NULL, -- Vincula el par salida/entrada del desempaque
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Índices para alto rendimiento y consultas de auditoría
CREATE INDEX IF NOT EXISTS idx_movimientos_tenant_fecha ON public.movimientos_inventario(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_movimientos_producto ON public.movimientos_inventario(producto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON public.movimientos_inventario(tipo_movimiento);
CREATE INDEX IF NOT EXISTS idx_productos_hijo ON public.productos(producto_hijo_id) WHERE producto_hijo_id IS NOT NULL;

-- 4. Inmutabilidad Estricta: Prohibir UPDATE y DELETE en movimientos_inventario
CREATE OR REPLACE FUNCTION public.fn_prohibir_modificacion_movimientos()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Los movimientos de inventario son inmutables por auditoría contable. No se permite UPDATE ni DELETE.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prohibir_modificacion_movimientos ON public.movimientos_inventario;
CREATE TRIGGER trg_prohibir_modificacion_movimientos
BEFORE UPDATE OR DELETE ON public.movimientos_inventario
FOR EACH ROW
EXECUTE FUNCTION public.fn_prohibir_modificacion_movimientos();

-- 5. Row Level Security (RLS)
ALTER TABLE public.movimientos_inventario ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir consultar movimientos" 
ON public.movimientos_inventario FOR SELECT USING (true);

CREATE POLICY "Permitir registrar movimientos" 
ON public.movimientos_inventario FOR INSERT WITH CHECK (true);

-- 6. RPC: Función Transaccional Atómica para Desempaque Mayorista
-- Ejecuta la resta de cajas, suma de unidades e inserción de 2 registros de auditoría vinculados
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
    v_nuevo_stock_unidades NUMERIC;
    v_unidades_a_sumar NUMERIC;
    v_costo_unitario_hijo NUMERIC;
    v_costo_total NUMERIC;
    v_salida_id UUID := gen_random_uuid();
    v_entrada_id UUID := gen_random_uuid();
BEGIN
    IF p_cantidad_cajas <= 0 THEN
        RAISE EXCEPTION 'La cantidad de cajas a desempaquetar debe ser mayor a 0';
    END IF;

    -- Bloqueo transaccional de la caja
    SELECT stock_actual, costo_mayorista, COALESCE(unidades_por_empaque, 1.0)
    INTO v_stock_caja, v_costo_caja, v_factor_unidades
    FROM public.productos
    WHERE id = p_caja_id AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto caja no encontrado en el tenant especificado';
    END IF;

    IF v_stock_caja < p_cantidad_cajas THEN
        RAISE EXCEPTION 'Stock insuficiente de cajas para desempaquetar (Disponible: %, Solicitado: %)', v_stock_caja, p_cantidad_cajas;
    END IF;

    -- Bloqueo transaccional del producto unidades destino
    PERFORM 1 FROM public.productos 
    WHERE id = p_unidades_id AND tenant_id = p_tenant_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto unidades destino no encontrado en el tenant especificado';
    END IF;

    v_unidades_a_sumar := p_cantidad_cajas * v_factor_unidades;
    v_costo_total := v_costo_caja * p_cantidad_cajas;
    v_costo_unitario_hijo := CASE WHEN v_factor_unidades > 0 THEN v_costo_caja / v_factor_unidades ELSE 0.0 END;

    -- 1. Descontar las cajas del inventario
    UPDATE public.productos
    SET stock_actual = stock_actual - p_cantidad_cajas,
        updated_at = NOW()
    WHERE id = p_caja_id
    RETURNING stock_actual INTO v_nuevo_stock_caja;

    -- 2. Sumar las botellas/unidades sueltas al inventario
    UPDATE public.productos
    SET stock_actual = stock_actual + v_unidades_a_sumar,
        updated_at = NOW()
    WHERE id = p_unidades_id
    RETURNING stock_actual INTO v_nuevo_stock_unidades;

    -- 3. Registrar auditoría inmutable de salida de cajas
    INSERT INTO public.movimientos_inventario (
        id, tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id
    ) VALUES (
        v_salida_id, p_tenant_id, p_caja_id, 'DESEMPAQUE_SALIDA', p_cantidad_cajas,
        v_costo_caja, v_costo_total, COALESCE(p_motivo, 'Desempaque a unidades sueltas'), v_entrada_id
    );

    -- 4. Registrar auditoría inmutable de entrada de botellas
    INSERT INTO public.movimientos_inventario (
        id, tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id
    ) VALUES (
        v_entrada_id, p_tenant_id, p_unidades_id, 'DESEMPAQUE_ENTRADA', v_unidades_a_sumar,
        v_costo_unitario_hijo, v_costo_total, COALESCE(p_motivo, 'Entrada generada por desempaque de caja'), v_salida_id
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

-- 7. RPC: Función Transaccional para Registro de Mermas y Roturas con Costo Financiero
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

    -- 1. Descontar stock del producto
    UPDATE public.productos
    SET stock_actual = stock_actual - p_cantidad,
        updated_at = NOW()
    WHERE id = p_producto_id
    RETURNING stock_actual INTO v_nuevo_stock;

    -- 2. Registrar movimiento inmutable con su costo financiero total
    INSERT INTO public.movimientos_inventario (
        id, tenant_id, producto_id, tipo_movimiento, cantidad,
        costo_unitario, costo_total, motivo, referencia_id
    ) VALUES (
        v_movimiento_id, p_tenant_id, p_producto_id, p_tipo_merma, p_cantidad,
        v_costo_unitario, v_costo_total, COALESCE(p_motivo, 'Registro de merma de inventario'), NULL
    );

    RETURN jsonb_build_object(
        'success', true,
        'cantidad_merma', p_cantidad,
        'costo_perdida', v_costo_total,
        'nuevo_stock', v_nuevo_stock
    );
END;
$$ LANGUAGE plpgsql;
