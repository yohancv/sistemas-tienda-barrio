-- ============================================================
-- Migración 11: Módulo de Gestión de Proveedores y Compras
-- (Reabastecimiento de Stock, Origen de Fondos, Trazabilidad y Kardex)
-- ============================================================

-- 1. Tabla de Proveedores / Distribuidores
CREATE TABLE IF NOT EXISTS public.proveedores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    nombre_empresa VARCHAR(150) NOT NULL, -- ej. "Cervecería Boliviana Nacional - CBN", "Embol Coca-Cola"
    nombre_contacto VARCHAR(100) NULL,    -- ej. "Carlos - Preventista"
    telefono VARCHAR(50) NULL,            -- Celular o teléfono para WhatsApp
    nit_ci VARCHAR(50) NULL,              -- Para facturación o identificación
    dias_visita VARCHAR(100) NULL,        -- ej. "Martes y Viernes"
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Vincular proveedor predeterminado en la tabla productos ("CBN no vende aceite")
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS proveedor_id UUID NULL REFERENCES public.proveedores(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_productos_proveedor ON public.productos(proveedor_id);

-- 3. Tabla de Compras (Cabecera de Factura / Nota de Entrega)
CREATE TABLE IF NOT EXISTS public.compras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    proveedor_id UUID NULL REFERENCES public.proveedores(id) ON DELETE SET NULL,
    numero_comprobante VARCHAR(50) NULL, -- N° de factura, recibo o nota de entrega
    total_compra NUMERIC(12, 2) NOT NULL CHECK (total_compra >= 0),
    metodo_pago VARCHAR(30) NOT NULL CHECK (
        metodo_pago IN ('EFECTIVO_CAJA', 'EFECTIVO_EXTERNO_ATM', 'QR_BANCO', 'PAGO_MIXTO')
    ),
    monto_pagado_caja NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (monto_pagado_caja >= 0),
    monto_pagado_externo NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (monto_pagado_externo >= 0),
    caja_turno_id UUID NULL REFERENCES public.cajas_turnos(id),
    observaciones TEXT NULL,
    fecha_compra TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    usuario_id UUID NULL,
    CONSTRAINT check_suma_pagos_compra CHECK (
        ABS((monto_pagado_caja + monto_pagado_externo) - total_compra) < 0.02
    )
);

-- 4. Tabla Detalle de Compras (Líneas de Mercadería Recibida)
CREATE TABLE IF NOT EXISTS public.detalle_compras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    compra_id UUID NOT NULL REFERENCES public.compras(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    cantidad NUMERIC(12, 3) NOT NULL CHECK (cantidad > 0),
    costo_unitario NUMERIC(12, 2) NOT NULL CHECK (costo_unitario >= 0),
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    nuevo_precio_venta NUMERIC(12, 2) NULL -- Si se ajustó el precio de mostrador al reabastecer
);

-- 5. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_proveedores_tenant_activo 
ON public.proveedores(tenant_id, activo);

CREATE INDEX IF NOT EXISTS idx_compras_tenant_fecha 
ON public.compras(tenant_id, fecha_compra DESC);

CREATE INDEX IF NOT EXISTS idx_compras_proveedor 
ON public.compras(proveedor_id);

CREATE INDEX IF NOT EXISTS idx_compras_caja_turno 
ON public.compras(caja_turno_id);

CREATE INDEX IF NOT EXISTS idx_detalle_compras_compra 
ON public.detalle_compras(compra_id);

CREATE INDEX IF NOT EXISTS idx_detalle_compras_producto 
ON public.detalle_compras(producto_id);

-- 6. Habilitar Row Level Security (RLS)
ALTER TABLE public.proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_compras ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir consultar proveedores" 
ON public.proveedores FOR SELECT USING (true);

CREATE POLICY "Permitir gestionar proveedores" 
ON public.proveedores FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir consultar compras" 
ON public.compras FOR SELECT USING (true);

CREATE POLICY "Permitir registrar compras" 
ON public.compras FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir consultar detalle compras" 
ON public.detalle_compras FOR SELECT USING (true);

CREATE POLICY "Permitir registrar detalle compras" 
ON public.detalle_compras FOR ALL USING (true) WITH CHECK (true);

-- 7. Función RPC Transaccional: Registro Atómico de Compra de Mercadería
-- Inserta la compra, suma stock actual, actualiza costo mayorista y precio venta,
-- genera la ENTRADA_COMPRA en movimientos_inventario y descuenta de caja si hubo egreso de turno.
CREATE OR REPLACE FUNCTION public.fn_registrar_compra_mercaderia(
    p_compra JSONB,
    p_detalles JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_compra_id UUID := gen_random_uuid();
    v_tenant_id UUID;
    v_proveedor_id UUID;
    v_numero_comprobante VARCHAR;
    v_total_compra NUMERIC;
    v_metodo_pago VARCHAR;
    v_monto_pagado_caja NUMERIC;
    v_monto_pagado_externo NUMERIC;
    v_caja_turno_id UUID;
    v_observaciones TEXT;
    v_item JSONB;
    v_producto_id UUID;
    v_cantidad NUMERIC;
    v_costo_unitario NUMERIC;
    v_subtotal NUMERIC;
    v_nuevo_precio_venta NUMERIC;
    v_stock_actual NUMERIC;
    v_stock_posterior NUMERIC;
    v_proveedor_nombre VARCHAR := 'Proveedor';
    v_ticket_corto VARCHAR;
BEGIN
    -- 1. Extraer y validar parámetros de cabecera
    v_tenant_id := (p_compra->>'tenant_id')::UUID;
    v_total_compra := (p_compra->>'total_compra')::NUMERIC;
    v_metodo_pago := p_compra->>'metodo_pago';
    v_monto_pagado_caja := COALESCE((p_compra->>'monto_pagado_caja')::NUMERIC, 0.00);
    v_monto_pagado_externo := COALESCE((p_compra->>'monto_pagado_externo')::NUMERIC, 0.00);
    v_numero_comprobante := p_compra->>'numero_comprobante';
    v_observaciones := p_compra->>'observaciones';

    IF p_compra ? 'proveedor_id' AND (p_compra->>'proveedor_id') IS NOT NULL AND (p_compra->>'proveedor_id') <> '' THEN
        v_proveedor_id := (p_compra->>'proveedor_id')::UUID;
        SELECT nombre_empresa INTO v_proveedor_nombre 
        FROM public.proveedores 
        WHERE id = v_proveedor_id;
    END IF;

    IF p_compra ? 'caja_turno_id' AND (p_compra->>'caja_turno_id') IS NOT NULL AND (p_compra->>'caja_turno_id') <> '' THEN
        v_caja_turno_id := (p_compra->>'caja_turno_id')::UUID;
    END IF;

    -- Validar que la suma de pagos coincida con el total
    IF ABS((v_monto_pagado_caja + v_monto_pagado_externo) - v_total_compra) >= 0.02 THEN
        RAISE EXCEPTION 'La suma de pagos (Caja: % + Externo: %) no coincide con el total de la compra: %',
            v_monto_pagado_caja, v_monto_pagado_externo, v_total_compra;
    END IF;

    -- Si se paga con dinero de caja, validar que haya un turno de caja activo especificado
    IF v_monto_pagado_caja > 0 THEN
        IF v_caja_turno_id IS NULL THEN
            RAISE EXCEPTION 'Debe especificar una caja de turno activa para registrar un egreso de efectivo.';
        END IF;

        PERFORM 1 FROM public.cajas_turnos 
        WHERE id = v_caja_turno_id AND tenant_id = v_tenant_id AND estado = 'ABIERTA';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El turno de caja especificado (%) no existe o ya se encuentra cerrado.', v_caja_turno_id;
        END IF;
    END IF;

    -- 2. Insertar cabecera en la tabla compras
    INSERT INTO public.compras (
        id,
        tenant_id,
        proveedor_id,
        numero_comprobante,
        total_compra,
        metodo_pago,
        monto_pagado_caja,
        monto_pagado_externo,
        caja_turno_id,
        observaciones,
        fecha_compra
    ) VALUES (
        v_compra_id,
        v_tenant_id,
        v_proveedor_id,
        v_numero_comprobante,
        v_total_compra,
        v_metodo_pago,
        v_monto_pagado_caja,
        v_monto_pagado_externo,
        v_caja_turno_id,
        v_observaciones,
        NOW()
    );

    v_ticket_corto := SUBSTRING(v_compra_id::TEXT, 1, 8);

    -- 3. Procesar cada detalle de producto
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        v_producto_id := (v_item->>'producto_id')::UUID;
        v_cantidad := (v_item->>'cantidad')::NUMERIC;
        v_costo_unitario := (v_item->>'costo_unitario')::NUMERIC;
        v_subtotal := (v_item->>'subtotal')::NUMERIC;
        
        IF v_item ? 'nuevo_precio_venta' AND (v_item->>'nuevo_precio_venta') IS NOT NULL THEN
            v_nuevo_precio_venta := (v_item->>'nuevo_precio_venta')::NUMERIC;
        ELSE
            v_nuevo_precio_venta := NULL;
        END IF;

        IF v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad comprada debe ser mayor a 0.';
        END IF;

        -- 3.1. Insertar línea de detalle
        INSERT INTO public.detalle_compras (
            compra_id,
            producto_id,
            cantidad,
            costo_unitario,
            subtotal,
            nuevo_precio_venta
        ) VALUES (
            v_compra_id,
            v_producto_id,
            v_cantidad,
            v_costo_unitario,
            v_subtotal,
            v_nuevo_precio_venta
        );

        -- 3.2. Bloquear producto y obtener stock_actual
        SELECT stock_actual INTO v_stock_actual
        FROM public.productos
        WHERE id = v_producto_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto con ID % no encontrado.', v_producto_id;
        END IF;

        v_stock_posterior := v_stock_actual + v_cantidad;

        -- 3.3. Actualizar stock_actual, costo_mayorista, proveedor y opcionalmente precio_venta
        UPDATE public.productos
        SET 
            stock_actual = v_stock_posterior,
            costo_mayorista = v_costo_unitario,
            precio_venta = CASE 
                WHEN v_nuevo_precio_venta IS NOT NULL AND v_nuevo_precio_venta > 0 
                THEN v_nuevo_precio_venta 
                ELSE precio_venta 
            END,
            proveedor_id = CASE 
                WHEN proveedor_id IS NULL AND v_proveedor_id IS NOT NULL 
                THEN v_proveedor_id 
                ELSE proveedor_id 
            END,
            updated_at = NOW()
        WHERE id = v_producto_id;

        -- 3.4. Registrar entrada inmutable en movimientos_inventario (Kardex)
        INSERT INTO public.movimientos_inventario (
            tenant_id,
            producto_id,
            tipo_movimiento,
            cantidad,
            costo_unitario,
            costo_total,
            motivo,
            referencia_id,
            stock_anterior,
            stock_posterior,
            created_at
        ) VALUES (
            v_tenant_id,
            v_producto_id,
            'ENTRADA_COMPRA',
            v_cantidad,
            v_costo_unitario,
            (v_costo_unitario * v_cantidad),
            'Reabastecimiento compra ' || COALESCE(v_proveedor_nombre, '') || ' (Ticket #' || v_ticket_corto || ')',
            v_compra_id,
            v_stock_actual,
            v_stock_posterior,
            NOW()
        );
    END LOOP;

    -- 4. Si hubo pago con efectivo de caja, registrar egreso en movimientos_caja
    IF v_monto_pagado_caja > 0 AND v_caja_turno_id IS NOT NULL THEN
        INSERT INTO public.movimientos_caja (
            tenant_id,
            turno_id,
            tipo,
            monto,
            motivo,
            created_at
        ) VALUES (
            v_tenant_id,
            v_caja_turno_id,
            'SALIDA',
            v_monto_pagado_caja,
            'Pago compra mercadería - ' || COALESCE(v_proveedor_nombre, 'Proveedor') || ' (Ticket #' || v_ticket_corto || ')',
            NOW()
        );
    END IF;

    -- 5. Retornar confirmación exitosa
    RETURN jsonb_build_object(
        'success', true,
        'compra_id', v_compra_id,
        'total_compra', v_total_compra,
        'monto_caja', v_monto_pagado_caja,
        'monto_externo', v_monto_pagado_externo,
        'proveedor', v_proveedor_nombre,
        'items_count', jsonb_array_length(p_detalles)
    );
END;
$$ LANGUAGE plpgsql;
