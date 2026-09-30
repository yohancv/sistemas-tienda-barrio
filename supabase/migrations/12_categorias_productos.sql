-- ============================================================
-- Migración 12: Categorías de Productos
-- (Clasificación por familia para Catálogo, POS y Pedidos a Proveedores)
-- ============================================================

-- 1. Agregar columna categoria en la tabla productos
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS categoria VARCHAR(100) NULL;

-- 2. Índice compuesto para búsquedas rápidas por tenant y categoría
CREATE INDEX IF NOT EXISTS idx_productos_tenant_categoria 
ON public.productos(tenant_id, categoria);
