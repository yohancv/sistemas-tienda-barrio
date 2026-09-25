-- 1. Tabla de Ventas (Cabecera inmutable)
CREATE TABLE IF NOT EXISTS public.ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    cliente_id UUID NULL, -- Requerido cuando es CREDITO_FIADO
    total_venta NUMERIC(12, 2) NOT NULL CHECK (total_venta >= 0),
    metodo_pago VARCHAR(20) NOT NULL CHECK (metodo_pago IN ('EFECTIVO', 'QR', 'MIXTO', 'CREDITO_FIADO')),
    monto_recibido NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cambio_entregado NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    fecha_venta TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla Detalle de Ventas (Líneas de productos con costo congelado)
CREATE TABLE IF NOT EXISTS public.detalle_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id UUID NOT NULL REFERENCES public.ventas(id) ON DELETE RESTRICT,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    cantidad NUMERIC(12, 3) NOT NULL CHECK (cantidad > 0), -- Soporte granel (kg/g)
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
    costo_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00, -- Congela el costo para Utilidad Neta real
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0)
);

-- 3. Tabla de Pagos de Ventas (Soporte exacto para Pagos Mixtos y Cashback)
CREATE TABLE IF NOT EXISTS public.pagos_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id UUID NOT NULL REFERENCES public.ventas(id) ON DELETE RESTRICT,
    tenant_id UUID NOT NULL,
    metodo VARCHAR(20) NOT NULL CHECK (metodo IN ('EFECTIVO', 'QR', 'TARJETA', 'FIADO')),
    monto NUMERIC(12, 2) NOT NULL, -- Permite montos negativos exclusivamente para Cashback/Vuelto
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Índices para alto rendimiento y consultas Multi-Tenant
CREATE INDEX IF NOT EXISTS idx_ventas_tenant_fecha ON public.ventas(tenant_id, fecha_venta DESC);
CREATE INDEX IF NOT EXISTS idx_ventas_cliente ON public.ventas(cliente_id) WHERE cliente_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_venta ON public.detalle_ventas(venta_id);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_producto ON public.detalle_ventas(producto_id);
CREATE INDEX IF NOT EXISTS idx_pagos_ventas_venta ON public.pagos_ventas(venta_id);

-- 5. Habilitación de Row Level Security (RLS)
ALTER TABLE public.ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos_ventas ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de RLS: SOLO LECTURA E INSERCIÓN (Inmutabilidad financiera absoluta)
CREATE POLICY "Permitir consultar ventas" ON public.ventas FOR SELECT USING (true);
CREATE POLICY "Permitir registrar ventas" ON public.ventas FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir consultar detalle" ON public.detalle_ventas FOR SELECT USING (true);
CREATE POLICY "Permitir registrar detalle" ON public.detalle_ventas FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir consultar pagos" ON public.pagos_ventas FOR SELECT USING (true);
CREATE POLICY "Permitir registrar pagos" ON public.pagos_ventas FOR INSERT WITH CHECK (true);
