-- ============================================================
-- Migración 09: Módulo de Cierre de Caja y Arqueo de Turno
-- (Control de Efectivo, Ventas QR, Fiados y Conteo Ciego)
-- ============================================================

-- 1. Tabla de Turnos / Sesiones de Caja
CREATE TABLE IF NOT EXISTS public.cajas_turnos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    usuario_id UUID NULL,
    fecha_apertura TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    monto_inicial NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (monto_inicial >= 0),
    fecha_cierre TIMESTAMPTZ NULL,
    total_ventas_efectivo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_ventas_qr NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_fiados_otorgados NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_fiados_cobrados_efectivo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_fiados_cobrados_qr NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_salidas_manuales NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_entradas_manuales NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    monto_esperado_efectivo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    monto_real_contado NUMERIC(12, 2) NULL,
    diferencia NUMERIC(12, 2) NULL,
    desglose_efectivo JSONB NULL, -- Desglose de billetes y monedas contadas
    observaciones_cierre TEXT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ABIERTA' CHECK (estado IN ('ABIERTA', 'CERRADA')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla de Movimientos Manuales de Caja (Ingresos y Egresos menores)
CREATE TABLE IF NOT EXISTS public.movimientos_caja (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    turno_id UUID NOT NULL REFERENCES public.cajas_turnos(id) ON DELETE CASCADE,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    monto NUMERIC(12, 2) NOT NULL CHECK (monto > 0),
    motivo VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Vincular ventas y abonos de deuda al turno de caja activo
ALTER TABLE public.ventas 
ADD COLUMN IF NOT EXISTS caja_turno_id UUID NULL REFERENCES public.cajas_turnos(id);

ALTER TABLE public.abonos_deuda 
ADD COLUMN IF NOT EXISTS caja_turno_id UUID NULL REFERENCES public.cajas_turnos(id);

-- 4. Índices para alto rendimiento y consultas Multi-Tenant
CREATE INDEX IF NOT EXISTS idx_cajas_turnos_tenant_estado 
ON public.cajas_turnos(tenant_id, estado);

CREATE INDEX IF NOT EXISTS idx_cajas_turnos_fecha 
ON public.cajas_turnos(tenant_id, fecha_apertura DESC);

CREATE INDEX IF NOT EXISTS idx_movimientos_caja_turno 
ON public.movimientos_caja(turno_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ventas_caja_turno 
ON public.ventas(caja_turno_id);

CREATE INDEX IF NOT EXISTS idx_abonos_caja_turno 
ON public.abonos_deuda(caja_turno_id);

-- 5. Habilitar Row Level Security (RLS)
ALTER TABLE public.cajas_turnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_caja ENABLE ROW LEVEL SECURITY;

-- Políticas de cajas_turnos: Lectura, Inserción y Actualización de cierre
CREATE POLICY "Permitir consultar turnos de caja" 
ON public.cajas_turnos FOR SELECT USING (true);

CREATE POLICY "Permitir abrir turnos de caja" 
ON public.cajas_turnos FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir actualizar turnos de caja" 
ON public.cajas_turnos FOR UPDATE USING (true) WITH CHECK (true);

-- Políticas de movimientos_caja
CREATE POLICY "Permitir consultar movimientos de caja" 
ON public.movimientos_caja FOR SELECT USING (true);

CREATE POLICY "Permitir registrar movimientos de caja" 
ON public.movimientos_caja FOR INSERT WITH CHECK (true);

-- 6. Función RPC para cálculo consolidado en vivo de un turno de caja
CREATE OR REPLACE FUNCTION public.fn_resumen_turno_caja(p_turno_id UUID, p_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_turno RECORD;
    v_ventas_efectivo NUMERIC := 0.00;
    v_ventas_qr NUMERIC := 0.00;
    v_fiados_otorgados NUMERIC := 0.00;
    v_fiados_cobrados_efectivo NUMERIC := 0.00;
    v_fiados_cobrados_qr NUMERIC := 0.00;
    v_entradas_manuales NUMERIC := 0.00;
    v_salidas_manuales NUMERIC := 0.00;
    v_monto_esperado NUMERIC := 0.00;
    v_fecha_fin TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_turno
    FROM public.cajas_turnos
    WHERE id = p_turno_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno de caja no encontrado';
    END IF;

    v_fecha_fin := COALESCE(v_turno.fecha_cierre, NOW());

    -- 1. Ventas en Efectivo (sumando los pagos_ventas de ventas de este turno o rango)
    SELECT COALESCE(SUM(pv.monto), 0.00) INTO v_ventas_efectivo
    FROM public.pagos_ventas pv
    JOIN public.ventas v ON v.id = pv.venta_id
    WHERE pv.tenant_id = p_tenant_id
      AND pv.metodo = 'EFECTIVO'
      AND (v.caja_turno_id = p_turno_id OR (v.caja_turno_id IS NULL AND v.fecha_venta >= v_turno.fecha_apertura AND v.fecha_venta <= v_fecha_fin));

    -- 2. Ventas por QR
    SELECT COALESCE(SUM(pv.monto), 0.00) INTO v_ventas_qr
    FROM public.pagos_ventas pv
    JOIN public.ventas v ON v.id = pv.venta_id
    WHERE pv.tenant_id = p_tenant_id
      AND pv.metodo = 'QR'
      AND (v.caja_turno_id = p_turno_id OR (v.caja_turno_id IS NULL AND v.fecha_venta >= v_turno.fecha_apertura AND v.fecha_venta <= v_fecha_fin));

    -- 3. Fiados Otorgados (Ventas a crédito)
    SELECT COALESCE(SUM(v.total_venta), 0.00) INTO v_fiados_otorgados
    FROM public.ventas v
    WHERE v.tenant_id = p_tenant_id
      AND v.metodo_pago = 'CREDITO_FIADO'
      AND (v.caja_turno_id = p_turno_id OR (v.caja_turno_id IS NULL AND v.fecha_venta >= v_turno.fecha_apertura AND v.fecha_venta <= v_fecha_fin));

    -- 4. Fiados Cobrados en Efectivo (Abonos)
    SELECT COALESCE(SUM(monto), 0.00) INTO v_fiados_cobrados_efectivo
    FROM public.abonos_deuda
    WHERE tenant_id = p_tenant_id
      AND metodo_pago = 'EFECTIVO'
      AND (caja_turno_id = p_turno_id OR (caja_turno_id IS NULL AND fecha_abono >= v_turno.fecha_apertura AND fecha_abono <= v_fecha_fin));

    -- 5. Fiados Cobrados por QR
    SELECT COALESCE(SUM(monto), 0.00) INTO v_fiados_cobrados_qr
    FROM public.abonos_deuda
    WHERE tenant_id = p_tenant_id
      AND metodo_pago IN ('QR', 'TRANSFERENCIA')
      AND (caja_turno_id = p_turno_id OR (caja_turno_id IS NULL AND fecha_abono >= v_turno.fecha_apertura AND fecha_abono <= v_fecha_fin));

    -- 6. Entradas Manuales de Caja
    SELECT COALESCE(SUM(monto), 0.00) INTO v_entradas_manuales
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id AND tipo = 'ENTRADA';

    -- 7. Salidas Manuales de Caja
    SELECT COALESCE(SUM(monto), 0.00) INTO v_salidas_manuales
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id AND tipo = 'SALIDA';

    -- 8. Monto Esperado en Efectivo en Cajón:
    -- Monto Inicial + Ventas Efectivo + Fiados Cobrados en Efectivo + Entradas Manuales - Salidas Manuales
    v_monto_esperado := v_turno.monto_inicial + v_ventas_efectivo + v_fiados_cobrados_efectivo + v_entradas_manuales - v_salidas_manuales;

    RETURN jsonb_build_object(
        'turno_id', p_turno_id,
        'estado', v_turno.estado,
        'fecha_apertura', v_turno.fecha_apertura,
        'monto_inicial', v_turno.monto_inicial,
        'total_ventas_efectivo', v_ventas_efectivo,
        'total_ventas_qr', v_ventas_qr,
        'total_fiados_otorgados', v_fiados_otorgados,
        'total_fiados_cobrados_efectivo', v_fiados_cobrados_efectivo,
        'total_fiados_cobrados_qr', v_fiados_cobrados_qr,
        'total_entradas_manuales', v_entradas_manuales,
        'total_salidas_manuales', v_salidas_manuales,
        'monto_esperado_efectivo', v_monto_esperado
    );
END;
$$ LANGUAGE plpgsql;
