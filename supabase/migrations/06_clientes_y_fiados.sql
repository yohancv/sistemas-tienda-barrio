-- ============================================================
-- Migración 06: Módulo de Cuentas por Cobrar (Deudores / Fiados)
-- Tablas inmutables, control de límites, triggers de sincronización
-- automática de saldo y función RPC de abonos.
-- ============================================================

-- 1. Tabla de Clientes con Límite de Crédito y Saldo Deudor
CREATE TABLE IF NOT EXISTS public.clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    telefono VARCHAR(50) NULL,
    limite_credito NUMERIC(12, 2) NOT NULL DEFAULT 100.00 CHECK (limite_credito >= 0),
    saldo_actual NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    notas TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla Inmutable de Abonos a Deuda (Historial de Pagos)
CREATE TABLE IF NOT EXISTS public.abonos_deuda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    cliente_id UUID NOT NULL REFERENCES public.clientes(id) ON DELETE RESTRICT,
    monto NUMERIC(12, 2) NOT NULL CHECK (monto > 0),
    metodo_pago VARCHAR(20) NOT NULL DEFAULT 'EFECTIVO' CHECK (metodo_pago IN ('EFECTIVO', 'QR', 'TRANSFERENCIA')),
    notas TEXT NULL,
    fecha_abono TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Índices para alto rendimiento y consultas Multi-Tenant
CREATE INDEX IF NOT EXISTS idx_clientes_tenant_saldo ON public.clientes(tenant_id, saldo_actual DESC);
CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON public.clientes(tenant_id, nombre);
CREATE INDEX IF NOT EXISTS idx_abonos_cliente_fecha ON public.abonos_deuda(cliente_id, fecha_abono DESC);
CREATE INDEX IF NOT EXISTS idx_abonos_tenant ON public.abonos_deuda(tenant_id, fecha_abono DESC);

-- 4. Inmutabilidad Estricta: Prohibir UPDATE y DELETE en abonos_deuda
CREATE OR REPLACE FUNCTION public.fn_prohibir_modificacion_abonos()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Los abonos de deuda son inmutables por auditoría contable. No se permite UPDATE ni DELETE.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prohibir_modificacion_abonos ON public.abonos_deuda;
CREATE TRIGGER trg_prohibir_modificacion_abonos
BEFORE UPDATE OR DELETE ON public.abonos_deuda
FOR EACH ROW
EXECUTE FUNCTION public.fn_prohibir_modificacion_abonos();

-- 5. Trigger: Actualizar saldo del cliente automáticamente cuando se registra un ABONO
CREATE OR REPLACE FUNCTION public.fn_sincronizar_saldo_cliente_por_abono()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.clientes
    SET saldo_actual = saldo_actual - NEW.monto,
        updated_at = NOW()
    WHERE id = NEW.cliente_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sincronizar_saldo_cliente_por_abono ON public.abonos_deuda;
CREATE TRIGGER trg_sincronizar_saldo_cliente_por_abono
AFTER INSERT ON public.abonos_deuda
FOR EACH ROW
EXECUTE FUNCTION public.fn_sincronizar_saldo_cliente_por_abono();

-- 6. Trigger: Actualizar saldo del cliente automáticamente cuando se registra una VENTA A CRÉDITO
CREATE OR REPLACE FUNCTION public.fn_sincronizar_saldo_cliente_por_venta()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.metodo_pago = 'CREDITO_FIADO' AND NEW.cliente_id IS NOT NULL THEN
        UPDATE public.clientes
        SET saldo_actual = saldo_actual + NEW.total_venta,
            updated_at = NOW()
        WHERE id = NEW.cliente_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sincronizar_saldo_cliente_por_venta ON public.ventas;
CREATE TRIGGER trg_sincronizar_saldo_cliente_por_venta
AFTER INSERT ON public.ventas
FOR EACH ROW
EXECUTE FUNCTION public.fn_sincronizar_saldo_cliente_por_venta();

-- 7. Row Level Security (RLS)
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abonos_deuda ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir consultar clientes" ON public.clientes FOR SELECT USING (true);
CREATE POLICY "Permitir registrar clientes" ON public.clientes FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir actualizar clientes" ON public.clientes FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "Permitir consultar abonos" ON public.abonos_deuda FOR SELECT USING (true);
CREATE POLICY "Permitir registrar abonos" ON public.abonos_deuda FOR INSERT WITH CHECK (true);

-- 8. RPC: Función Transaccional para Registrar Abono a Deuda
CREATE OR REPLACE FUNCTION public.registrar_abono_deuda(
    p_cliente_id UUID,
    p_monto NUMERIC,
    p_metodo_pago VARCHAR,
    p_notas TEXT,
    p_tenant_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_saldo_actual NUMERIC;
    v_nuevo_saldo NUMERIC;
    v_abono_id UUID := gen_random_uuid();
    v_nombre_cliente VARCHAR;
BEGIN
    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a 0';
    END IF;

    -- Bloqueo transaccional del cliente
    SELECT nombre, saldo_actual INTO v_nombre_cliente, v_saldo_actual
    FROM public.clientes
    WHERE id = p_cliente_id AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado en el tenant especificado';
    END IF;

    -- Insertar abono (el trigger fn_sincronizar_saldo_cliente_por_abono actualizará el saldo automáticamente)
    INSERT INTO public.abonos_deuda (
        id, tenant_id, cliente_id, monto, metodo_pago, notas, fecha_abono
    ) VALUES (
        v_abono_id, p_tenant_id, p_cliente_id, p_monto,
        COALESCE(p_metodo_pago, 'EFECTIVO'), p_notas, NOW()
    );

    SELECT saldo_actual INTO v_nuevo_saldo
    FROM public.clientes
    WHERE id = p_cliente_id;

    RETURN jsonb_build_object(
        'success', true,
        'abono_id', v_abono_id,
        'cliente_id', p_cliente_id,
        'nombre_cliente', v_nombre_cliente,
        'monto_abonado', p_monto,
        'saldo_anterior', v_saldo_actual,
        'nuevo_saldo', v_nuevo_saldo
    );
END;
$$ LANGUAGE plpgsql;
