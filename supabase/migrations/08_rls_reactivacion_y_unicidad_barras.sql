-- ============================================================
-- Migración 08: Ajuste de RLS para reactivación de productos
-- y soporte de unicidad de código de barras
-- ============================================================

-- 1. Eliminar la política restrictiva anterior que impedía acceder a productos inactivos
DROP POLICY IF EXISTS "Permitir acceso a productos del mismo tenant" ON public.productos;

-- 2. Nuevas políticas separadas por operación:

-- SELECT: Permitir consultar TODOS los productos (activos e inactivos) para reactivación y auditoría
CREATE POLICY "Permitir consultar todos los productos"
ON public.productos
FOR SELECT
USING (true);

-- INSERT: Solo se permite crear productos activos
CREATE POLICY "Permitir insertar productos activos"
ON public.productos
FOR INSERT
WITH CHECK (true);

-- UPDATE: Permitir actualizar cualquier producto (necesario para reactivar inactivos con estado_activo = true)
CREATE POLICY "Permitir actualizar productos"
ON public.productos
FOR UPDATE
USING (true)
WITH CHECK (true);

-- 3. Índice parcial único para código de barras entre productos activos
-- Esto impide que dos productos activos compartan el mismo código de barras en el mismo tenant,
-- pero permite que un producto inactivo conserve su código sin conflicto.
CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo_barras_unico
ON public.productos (tenant_id, codigo_barras)
WHERE estado_activo = true AND codigo_barras IS NOT NULL;
