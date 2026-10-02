-- ============================================================
-- Migración 13: Subcategorías de Productos
-- Soporte para jerarquía de categorías en 2 niveles
-- (ej. Categoría: Cervezas -> Subcategoría / Tamaño: 710cc, Lata 354cc, etc.)
-- ============================================================

-- 1. Añadir columna subcategoria a la tabla productos
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS subcategoria VARCHAR(100) NULL;

-- 2. Índice compuesto para acelerar búsquedas y agrupaciones por categoría y subcategoría
CREATE INDEX IF NOT EXISTS idx_productos_tenant_cat_subcat 
ON public.productos(tenant_id, categoria, subcategoria);
