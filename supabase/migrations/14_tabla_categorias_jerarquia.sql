-- ============================================================
-- Migración 14: Tabla de Categorías y Subcategorías Jerárquicas
-- Permite organizar el catálogo en árbol (Categoría -> Subcategoría)
-- ============================================================

-- 1. Agregar columna opcional de precio venta de empaque mayorista en productos
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS precio_empaque_mayorista NUMERIC(12, 2) NULL;

-- 2. Crear tabla categorias
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(50) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    parent_id UUID NULL REFERENCES public.categorias(id) ON DELETE CASCADE,
    icono VARCHAR(50) NULL,
    orden INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_categorias_tenant_parent 
ON public.categorias(tenant_id, parent_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_categorias_tenant_parent_nombre 
ON public.categorias(tenant_id, COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(nombre));

-- 3. Habilitar RLS con política permisiva (coherente con las migraciones previas)
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'categorias' AND policyname = 'Permitir todo para categorias'
    ) THEN
        CREATE POLICY "Permitir todo para categorias" 
        ON public.categorias FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 4. Inserción de Categorías y Subcategorías base para el tenant predeterminado
DO $$
DECLARE
    v_tenant VARCHAR(50) := '00000000-0000-0000-0000-000000000000';
    v_cat_cervezas UUID;
    v_cat_gaseosas UUID;
    v_cat_coca UUID;
    v_cat_lacteos UUID;
    v_cat_golosinas UUID;
    v_cat_cigarros UUID;
    v_cat_abarrotes UUID;
    v_cat_limpieza UUID;
BEGIN
    -- Cervezas
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Cervezas', '🍺', 1)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_cervezas;
    IF v_cat_cervezas IS NULL THEN
        SELECT id INTO v_cat_cervezas FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'cervezas';
    END IF;

    -- Subcategorías Cervezas
    IF v_cat_cervezas IS NOT NULL THEN
        INSERT INTO public.categorias (tenant_id, nombre, parent_id, orden) VALUES
        (v_tenant, 'Huari', v_cat_cervezas, 1),
        (v_tenant, 'Paceña', v_cat_cervezas, 2),
        (v_tenant, 'Corona', v_cat_cervezas, 3),
        (v_tenant, 'Taquiña', v_cat_cervezas, 4),
        (v_tenant, 'Lata 354cc', v_cat_cervezas, 5),
        (v_tenant, '710cc', v_cat_cervezas, 6)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Gaseosas y Aguas
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Gaseosas y Aguas', '🥤', 2)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_gaseosas;
    IF v_cat_gaseosas IS NULL THEN
        SELECT id INTO v_cat_gaseosas FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'gaseosas y aguas';
    END IF;

    -- Subcategorías Gaseosas
    IF v_cat_gaseosas IS NOT NULL THEN
        INSERT INTO public.categorias (tenant_id, nombre, parent_id, orden) VALUES
        (v_tenant, 'Coca-Cola', v_cat_gaseosas, 1),
        (v_tenant, 'Pepsi', v_cat_gaseosas, 2),
        (v_tenant, 'Mendocina', v_cat_gaseosas, 3),
        (v_tenant, 'Vital', v_cat_gaseosas, 4),
        (v_tenant, '2 Litros', v_cat_gaseosas, 5),
        (v_tenant, 'Personal 500ml', v_cat_gaseosas, 6)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Coca y Derivados
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Coca y Derivados', '🌿', 3)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_coca;
    IF v_cat_coca IS NULL THEN
        SELECT id INTO v_cat_coca FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'coca y derivados';
    END IF;

    -- Subcategorías Coca
    IF v_cat_coca IS NOT NULL THEN
        INSERT INTO public.categorias (tenant_id, nombre, parent_id, orden) VALUES
        (v_tenant, 'Hoja de Coca (Por Libra)', v_cat_coca, 1),
        (v_tenant, 'Machucada Menta', v_cat_coca, 2),
        (v_tenant, 'Machucada Bico', v_cat_coca, 3),
        (v_tenant, 'Machucada Café', v_cat_coca, 4),
        (v_tenant, 'Bicarbonato', v_cat_coca, 5)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Lácteos y Embutidos
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Lácteos y Embutidos', '🥛', 4)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_lacteos;
    IF v_cat_lacteos IS NULL THEN
        SELECT id INTO v_cat_lacteos FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'lácteos y embutidos';
    END IF;

    -- Golosinas y Snacks
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Golosinas y Snacks', '🍪', 5)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_golosinas;
    IF v_cat_golosinas IS NULL THEN
        SELECT id INTO v_cat_golosinas FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'golosinas y snacks';
    END IF;

    -- Cigarrillos
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Cigarrillos', '🚬', 6)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_cigarros;
    IF v_cat_cigarros IS NULL THEN
        SELECT id INTO v_cat_cigarros FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'cigarrillos';
    END IF;

    -- Abarrotes
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Abarrotes y Alimentos', '🍞', 7)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_abarrotes;
    IF v_cat_abarrotes IS NULL THEN
        SELECT id INTO v_cat_abarrotes FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'abarrotes y alimentos';
    END IF;

    -- Limpieza
    INSERT INTO public.categorias (tenant_id, nombre, icono, orden)
    VALUES (v_tenant, 'Limpieza y Aseo', '🧼', 8)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_cat_limpieza;
    IF v_cat_limpieza IS NULL THEN
        SELECT id INTO v_cat_limpieza FROM public.categorias WHERE tenant_id = v_tenant AND parent_id IS NULL AND lower(nombre) = 'limpieza y aseo';
    END IF;
END $$;
