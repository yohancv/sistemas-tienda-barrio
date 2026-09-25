-- Tabla inmutable para Cierre de Caja Ciego
CREATE TABLE IF NOT EXISTS public.cierres_caja (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    fondo_fijo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    monto_declarado NUMERIC(12, 2) NULL, -- Nulo si se pospone
    monto_esperado NUMERIC(12, 2) NULL,  -- Calculado del sistema
    descuadre NUMERIC(12, 2) NULL,       -- Diferencia (sobrante o faltante)
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('COMPLETADO', 'POSPUESTO')),
    notas TEXT NULL,
    fecha_cierre TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices Multi-Tenant y de fecha
CREATE INDEX IF NOT EXISTS idx_cierres_tenant_fecha ON public.cierres_caja(tenant_id, fecha_cierre DESC);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.cierres_caja ENABLE ROW LEVEL SECURITY;

-- Políticas de Inmutabilidad Financiera: SOLO LECTURA E INSERCIÓN
CREATE POLICY "Permitir consultar cierres" ON public.cierres_caja FOR SELECT USING (true);
CREATE POLICY "Permitir registrar cierres" ON public.cierres_caja FOR INSERT WITH CHECK (true);
