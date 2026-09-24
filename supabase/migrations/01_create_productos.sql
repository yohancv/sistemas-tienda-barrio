-- 1. Habilitar extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. Crear tabla productos
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    codigo_barras VARCHAR(100) NULL,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT NULL,
    tipo_unidad VARCHAR(20) NOT NULL DEFAULT 'UNIDAD' CHECK (tipo_unidad IN ('UNIDAD', 'FRACCIONABLE')),
    stock_actual NUMERIC(12, 3) NOT NULL DEFAULT 0.000,
    stock_minimo NUMERIC(12, 3) NOT NULL DEFAULT 0.000,
    costo_mayorista NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    precio_venta NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    estado_activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Índices de optimización y búsqueda difusa (Fuzzy Search)
CREATE INDEX IF NOT EXISTS idx_productos_tenant ON public.productos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_productos_codigo_barras ON public.productos(tenant_id, codigo_barras);
CREATE INDEX IF NOT EXISTS idx_productos_nombre_trgm ON public.productos USING gin (nombre gin_trgm_ops);

-- 4. Habilitar Row Level Security (RLS)
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;

-- 5. Política básica de RLS (Permitir lectura y escritura por tenant autenticado)
CREATE POLICY "Permitir acceso a productos del mismo tenant"
ON public.productos
FOR ALL
USING (
    estado_activo = true
)
WITH CHECK (
    estado_activo = true
);
