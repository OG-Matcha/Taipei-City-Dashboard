-- Food inspection failure component seed
-- Target DB: postgres-manager
-- Component id=302, dashboard id=400

BEGIN;

-- ── 1. component_charts ───────────────────────────────────────────────────────
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
  'food_inspection_failures',
  '{"#dc2626","#f87171","#fca5a5"}',
  '{BarChart}',
  '筆'
)
ON CONFLICT (index) DO NOTHING;

-- ── 2. components ─────────────────────────────────────────────────────────────
INSERT INTO public.components (id, index, name)
VALUES (302, 'food_inspection_failures', '雙北食品抽驗不合格統計')
ON CONFLICT (id) DO NOTHING;

-- ── 3. component_maps: all districts (雙北) ───────────────────────────────────
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_inspection_failures',
  '食品抽驗不合格',
  'circle',
  'geojson',
  NULL,
  NULL,
  '{
    "circle-color": "#dc2626",
    "circle-opacity": 0.5,
    "circle-radius": ["interpolate", ["linear"], ["get", "num"], 0, 4, 5, 10, 15, 18, 36, 32],
    "circle-stroke-color": "#dc2626",
    "circle-stroke-width": 1.5,
    "circle-stroke-opacity": 0.85
  }',
  '[{"key":"district","name":"行政區"},{"key":"city","name":"縣市"},{"key":"num","name":"不合格筆數"}]'
WHERE NOT EXISTS (
  SELECT 1 FROM public.component_maps WHERE index = 'food_inspection_failures'
);

-- ── 4. component_maps: taipei only ────────────────────────────────────────────
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_inspection_failures_taipei',
  '臺北市食品抽驗不合格',
  'circle',
  'geojson',
  NULL,
  NULL,
  '{
    "circle-color": "#dc2626",
    "circle-opacity": 0.5,
    "circle-radius": ["interpolate", ["linear"], ["get", "num"], 0, 4, 5, 10, 15, 18, 36, 32],
    "circle-stroke-color": "#dc2626",
    "circle-stroke-width": 1.5,
    "circle-stroke-opacity": 0.85
  }',
  '[{"key":"district","name":"行政區"},{"key":"num","name":"不合格筆數"}]'
WHERE NOT EXISTS (
  SELECT 1 FROM public.component_maps WHERE index = 'food_inspection_failures_taipei'
);

-- ── 5. query_charts: metrotaipei (all 41 districts) ──────────────────────────
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES (
  'food_inspection_failures',
  NULL,
  ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_inspection_failures'),
  '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局 / 新北市政府衛生局',
  '雙北食品抽驗不合格行政區統計',
  '統計雙北各行政區食品商家抽驗不合格筆數，圓圈大小代表不合格數量。',
  '識別食安風險集中的行政區，協助稽查資源優先配置。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, num AS data
FROM (VALUES
  ('中山區',36),('大安區',36),('板橋區',30),('中正區',25),('士林區',25),
  ('萬華區',22),('松山區',21),('北投區',19),('新莊區',16),('信義區',14),
  ('大同區',13),('新店區',13),('中和區',12),('內湖區',12),('文山區',12),
  ('三重區',9),('蘆洲區',7),('樹林區',7),('永和區',5),('汐止區',4),
  ('土城區',3),('三峽區',3),('深坑區',3),('五股區',2),('金山區',2),
  ('南港區',2),('鶯歌區',0),('淡水區',0),('瑞芳區',0),('泰山區',0),
  ('林口區',0),('八里區',0),('石碇區',0),('坪林區',0),('三芝區',0),
  ('石門區',0),('萬里區',0),('平溪區',0),('雙溪區',0),('貢寮區',0),
  ('烏來區',0)
) AS t(district, num)
ORDER BY num DESC$SQL$,
  NULL, 'metrotaipei'
)
ON CONFLICT DO NOTHING;

-- ── 6. query_charts: taipei (12 districts) ───────────────────────────────────
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES (
  'food_inspection_failures',
  NULL,
  ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_inspection_failures_taipei'),
  '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局',
  '臺北市食品抽驗不合格行政區統計',
  '統計臺北市各行政區食品商家抽驗不合格筆數，圓圈大小代表不合格數量。',
  '識別臺北市食安風險集中的行政區，協助稽查資源優先配置。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, num AS data
FROM (VALUES
  ('中山區',36),('大安區',36),('中正區',25),('士林區',25),
  ('萬華區',22),('松山區',21),('北投區',19),('信義區',14),
  ('大同區',13),('內湖區',12),('文山區',12),('南港區',2)
) AS t(district, num)
ORDER BY num DESC$SQL$,
  NULL, 'taipei'
)
ON CONFLICT DO NOTHING;

-- ── 7. add component 302 to dashboard 400 ────────────────────────────────────
UPDATE public.dashboards
SET components = array_append(components, 302)
WHERE id = 400
  AND NOT (components @> ARRAY[302]);

COMMIT;
