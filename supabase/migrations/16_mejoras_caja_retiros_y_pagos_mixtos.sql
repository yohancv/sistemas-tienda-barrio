-- ============================================================
-- Migración 16: Mejoras en Control de Caja, Retiros Duales (Caja / QR)
-- y Separación de Gastos de Tienda vs Retiros Personales
-- ============================================================

-- 1. Agregar columnas a movimientos_caja para diferenciar origen del dinero y categoría
ALTER TABLE public.movimientos_caja 
ADD COLUMN IF NOT EXISTS origen_dinero VARCHAR(20) NOT NULL DEFAULT 'EFECTIVO_CAJA' 
CHECK (origen_dinero IN ('EFECTIVO_CAJA', 'BANCO_QR'));

ALTER TABLE public.movimientos_caja 
ADD COLUMN IF NOT EXISTS categoria VARCHAR(30) NOT NULL DEFAULT 'GASTO_TIENDA' 
CHECK (categoria IN ('GASTO_TIENDA', 'RETIRO_PERSONAL', 'MERCADERIA_FUTURA', 'AHORRO', 'PAGO_AYUDANTE', 'CAMBIO_SENCILLO', 'OTRO'));

-- 2. Agregar columnas a cajas_turnos para almacenar las métricas consolidadas al cierre
ALTER TABLE public.cajas_turnos
ADD COLUMN IF NOT EXISTS total_retiros_qr NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_salidas_tienda NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_salidas_personal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS saldo_neto_qr NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 3. Actualizar función RPC fn_resumen_turno_caja
CREATE OR REPLACE FUNCTION public.fn_resumen_turno_caja(p_turno_id UUID, p_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_turno RECORD;
    v_ventas_efectivo NUMERIC := 0.00;
    v_ventas_qr NUMERIC := 0.00;
    v_fiados_otorgados NUMERIC := 0.00;
    v_fiados_cobrados_efectivo NUMERIC := 0.00;
    v_fiados_cobrados_qr NUMERIC := 0.00;
    
    -- Movimientos en efectivo (cajón)
    v_entradas_caja NUMERIC := 0.00;
    v_salidas_caja NUMERIC := 0.00;
    
    -- Movimientos en cuenta bancaria / QR
    v_entradas_qr NUMERIC := 0.00;
    v_retiros_qr NUMERIC := 0.00;
    
    -- Clasificación por impacto financiero
    v_salidas_tienda NUMERIC := 0.00;
    v_salidas_personal NUMERIC := 0.00;
    v_mercaderia_futura NUMERIC := 0.00;
    
    -- Saldos resultantes
    v_monto_esperado_efectivo NUMERIC := 0.00;
    v_saldo_neto_qr NUMERIC := 0.00;
    
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

    -- 6. Movimientos de Caja Física (Efectivo)
    SELECT COALESCE(SUM(monto), 0.00) INTO v_entradas_caja
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'ENTRADA' 
      AND (origen_dinero = 'EFECTIVO_CAJA' OR origen_dinero IS NULL);

    SELECT COALESCE(SUM(monto), 0.00) INTO v_salidas_caja
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'SALIDA' 
      AND (origen_dinero = 'EFECTIVO_CAJA' OR origen_dinero IS NULL);

    -- 7. Movimientos de QR / Banco (Cajero ATM)
    SELECT COALESCE(SUM(monto), 0.00) INTO v_entradas_qr
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'ENTRADA' 
      AND origen_dinero = 'BANCO_QR';

    SELECT COALESCE(SUM(monto), 0.00) INTO v_retiros_qr
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'SALIDA' 
      AND origen_dinero = 'BANCO_QR';

    -- 8. Clasificación por propósito (Salidas de Tienda vs Personales vs Mercadería)
    SELECT COALESCE(SUM(monto), 0.00) INTO v_salidas_tienda
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'SALIDA' 
      AND categoria IN ('GASTO_TIENDA', 'PAGO_AYUDANTE', 'OTRO');

    SELECT COALESCE(SUM(monto), 0.00) INTO v_salidas_personal
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'SALIDA' 
      AND categoria IN ('RETIRO_PERSONAL', 'AHORRO');

    SELECT COALESCE(SUM(monto), 0.00) INTO v_mercaderia_futura
    FROM public.movimientos_caja
    WHERE turno_id = p_turno_id 
      AND tipo = 'SALIDA' 
      AND categoria = 'MERCADERIA_FUTURA';

    -- 9. Monto Esperado en Efectivo en Cajón:
    -- Monto Inicial + Ventas Efectivo + Fiados Cobrados en Efectivo + Entradas de Caja - Salidas de Caja
    v_monto_esperado_efectivo := v_turno.monto_inicial + v_ventas_efectivo + v_fiados_cobrados_efectivo + v_entradas_caja - v_salidas_caja;

    -- 10. Saldo Neto en Cuenta Bancaria / QR:
    -- Ventas QR + Fiados Cobrados en QR + Entradas QR - Retiros de QR por Cajero
    v_saldo_neto_qr := (v_ventas_qr + v_fiados_cobrados_qr + v_entradas_qr) - v_retiros_qr;

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
        'total_entradas_manuales', v_entradas_caja,
        'total_salidas_manuales', v_salidas_caja,
        'total_retiros_qr', v_retiros_qr,
        'total_salidas_tienda', v_salidas_tienda,
        'total_salidas_personal', v_salidas_personal,
        'total_mercaderia_futura', v_mercaderia_futura,
        'saldo_neto_qr', v_saldo_neto_qr,
        'monto_esperado_efectivo', v_monto_esperado_efectivo
    );
END;
$$ LANGUAGE plpgsql;
