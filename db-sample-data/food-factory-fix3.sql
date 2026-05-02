-- Fix: separate map layers per city (臺北市 vs 雙北)
-- Requires fix2 already applied.
-- Target DB: postgres-manager

BEGIN;

-- ── 1. Add taipei-only circle map layer ───────────────────────────────────────
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_factory_locations_taipei',
  '臺北市食品工廠',
  'circle',
  'geojson',
  'small',
  NULL,
  '{"circle-color":"#5b9fe8","circle-opacity":0.85,"circle-stroke-width":1,"circle-stroke-color":"#ffffff","circle-stroke-opacity":0.6}',
  '[{"key":"name","name":"工廠名稱"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"}]'
WHERE NOT EXISTS (
  SELECT 1 FROM public.component_maps WHERE index = 'food_factory_locations_taipei'
);

-- ── 2. taipei row → reference taipei-only map layer ──────────────────────────
UPDATE public.query_charts
SET map_config_ids = ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations_taipei'),
    map_filter = '{"mode":"byParam","byParam":{"xParam":"district"}}'
WHERE index = 'food_factory_district' AND city = 'taipei';

-- ── 3. metrotaipei row → keep all-factory map, update map_filter ─────────────
UPDATE public.query_charts
SET map_filter = '{"mode":"byParam","byParam":{"xParam":"district"}}'
WHERE index = 'food_factory_district' AND city = 'metrotaipei';

COMMIT;
