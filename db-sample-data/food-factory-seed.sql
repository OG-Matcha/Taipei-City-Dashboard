-- Food Factory component seed
-- Target DB: postgres-manager
-- ONE component: id=301, FoodFactoryChart chart + food_factory_locations map layer
-- Dashboard: id=400 (食安健康)

BEGIN;

-- ── 1. component_charts ───────────────────────────────────────────────────────
INSERT INTO public.component_charts (index, color, types, unit)
VALUES ('food_factory_district', '{"#5b9fe8","#f59e0b","#6b8fa3"}', '{FoodFactoryChart}', '家')
ON CONFLICT (index) DO NOTHING;

-- ── 2. components ─────────────────────────────────────────────────────────────
INSERT INTO public.components (id, index, name)
VALUES (301, 'food_factory_district', '雙北食品工廠行政區分布')
ON CONFLICT (id) DO NOTHING;

-- ── 3. component_maps (circle layer for all factory points) ──────────────────
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
  'food_factory_locations',
  '食品工廠',
  'circle',
  'geojson',
  'small',
  NULL,
  '{"circle-color":["match",["get","city"],"臺北市","#5b9fe8","新北市","#f59e0b","#6b8fa3"],"circle-opacity":0.85,"circle-stroke-width":1,"circle-stroke-color":"#ffffff","circle-stroke-opacity":0.6}',
  '[{"key":"name","name":"工廠名稱"},{"key":"city","name":"縣市"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"}]'
);

-- ── 4. query_charts ───────────────────────────────────────────────────────────
INSERT INTO public.query_charts (
  index, history_config,
  map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES (
  'food_factory_district',
  NULL,
  ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations'),
  '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局 / 新北市政府衛生局',
  '雙北食品工廠行政區統計',
  '統計臺北市與新北市各行政區的合法食品工廠登記數量，可切換城市查看各區分布狀況，地圖顯示每座工廠的實際位置（藍色：臺北市，橘色：新北市）。',
  '了解雙北食品製造業的地理分布，協助食安稽查資源配置規劃，可與學校供餐供應鏈圖對照，識別風險集中區域。',
  '{}', '{}', NOW(), NOW(),
  'static', 'static', NULL, 'metrotaipei'
)
ON CONFLICT DO NOTHING;

-- ── 5. Add component 301 to dashboard 400 ────────────────────────────────────
UPDATE public.dashboards
SET components = array_append(components, 301)
WHERE id = 400
  AND NOT (components @> ARRAY[301]);

COMMIT;
