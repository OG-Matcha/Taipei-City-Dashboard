-- ============================================================
-- Food Safety Dashboard — consolidated seed (matcha-dev)
-- Target DB: postgres-manager
-- Dashboard 400 (食安健康), Components 300-303
-- Run once on a fresh manager DB (idempotent via ON CONFLICT).
-- ============================================================

BEGIN;

-- ── component_charts ─────────────────────────────────────────────────────────
INSERT INTO public.component_charts (index, color, types, unit) VALUES
  ('school_food_supply_chain',  '{}',                                    '{SankeyChart}',             '次'),
  ('food_factory_district',     '{"#5b9fe8","#f59e0b","#6b8fa3"}',       '{DistrictChart,BarChart}',   '家'),
  ('food_inspection_failures',  '{"#dc2626","#f87171","#fca5a5"}',        '{BarChart}',                '筆'),
  ('rfsrai_index',              '{"#dc2626","#f87171","#fca5a5"}',        '{TreemapChart,DistrictChart}','pts')
ON CONFLICT (index) DO NOTHING;

-- ── components ───────────────────────────────────────────────────────────────
INSERT INTO public.components (id, index, name) VALUES
  (300, 'school_food_supply_chain', '雙北學校供餐供應鏈'),
  (301, 'food_factory_district',    '雙北食品工廠行政區分布'),
  (302, 'food_inspection_failures', '雙北食品抽驗不合格統計'),
  (303, 'rfsrai_index',             '區域食品安全風險評估指標 (RFSRAI)')
ON CONFLICT (id) DO NOTHING;

-- ── component_maps ───────────────────────────────────────────────────────────
-- 301 map: all factories (雙北)
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_factory_locations', '食品工廠', 'circle', 'geojson', 'small', NULL,
  '{"circle-color":["match",["get","city"],"臺北市","#5b9fe8","新北市","#f59e0b","#6b8fa3"],"circle-opacity":0.85,"circle-stroke-width":1,"circle-stroke-color":"#ffffff","circle-stroke-opacity":0.6}',
  '[{"key":"name","name":"工廠名稱"},{"key":"city","name":"縣市"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"}]'
WHERE NOT EXISTS (SELECT 1 FROM public.component_maps WHERE index = 'food_factory_locations');

-- 301 map: taipei-only factories
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_factory_locations_taipei', '臺北市食品工廠', 'circle', 'geojson', 'small', NULL,
  '{"circle-color":"#5b9fe8","circle-opacity":0.85,"circle-stroke-width":1,"circle-stroke-color":"#ffffff","circle-stroke-opacity":0.6}',
  '[{"key":"name","name":"工廠名稱"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"}]'
WHERE NOT EXISTS (SELECT 1 FROM public.component_maps WHERE index = 'food_factory_locations_taipei');

-- 302 map: inspection failures (雙北)
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_inspection_failures', '食品抽驗不合格', 'circle', 'geojson', NULL, NULL,
  '{"circle-color":"#dc2626","circle-opacity":0.5,"circle-radius":["interpolate",["linear"],["get","num"],0,4,5,10,15,18,36,32],"circle-stroke-color":"#dc2626","circle-stroke-width":1.5,"circle-stroke-opacity":0.85}',
  '[{"key":"district","name":"行政區"},{"key":"city","name":"縣市"},{"key":"num","name":"不合格筆數"}]'
WHERE NOT EXISTS (SELECT 1 FROM public.component_maps WHERE index = 'food_inspection_failures');

-- 302 map: inspection failures taipei-only
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
SELECT
  'food_inspection_failures_taipei', '臺北市食品抽驗不合格', 'circle', 'geojson', NULL, NULL,
  '{"circle-color":"#dc2626","circle-opacity":0.5,"circle-radius":["interpolate",["linear"],["get","num"],0,4,5,10,15,18,36,32],"circle-stroke-color":"#dc2626","circle-stroke-width":1.5,"circle-stroke-opacity":0.85}',
  '[{"key":"district","name":"行政區"},{"key":"num","name":"不合格筆數"}]'
WHERE NOT EXISTS (SELECT 1 FROM public.component_maps WHERE index = 'food_inspection_failures_taipei');

-- ── dashboard 400 ─────────────────────────────────────────────────────────────
INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (400, 'food_safety_health', '食安健康', '{300,301,302,303}', 'restaurant', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
VALUES (400, 3)
ON CONFLICT DO NOTHING;

-- ── query_charts ─────────────────────────────────────────────────────────────
-- 300 school_food_supply_chain (metrotaipei only, static sankey)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'school_food_supply_chain', NULL, '{}', '{}',
  'static', NULL, 0, NULL,
  '教育局',
  '雙北中小學及高中職供餐食材供應鏈（上游供應商 → 中游供餐業者 → 下游學校）',
  '本圖以桑基圖呈現雙北地區（臺北市、新北市）中小學及高中職學校的供餐供應鏈結構。上游為食材及調味料供應商，中游為各供餐業者，下游為學校。連結寬度代表供貨次數，顯示各供應商與供餐業者之間的合作密度，以及供餐業者服務學校的頻率。可依市縣篩選查看臺北市或新北市的供應鏈分布。',
  '適用於食品安全稽查、供應鏈風險評估及教育餐飲管理。透過視覺化供應鏈關係，可快速識別高風險供應商（供貨次數異常集中）、單一業者依賴風險，以及跨市供應商的分布情形，支援食安政策制定與應急追溯。',
  '{https://data.taipei/dataset/detail?id=school-food-supply}',
  '{doit,ntpc}', NOW(), NOW(),
  'static', 'static', NULL, 'metrotaipei'
) ON CONFLICT DO NOTHING;

-- 301 food_factory_district — metrotaipei (全部 34 區)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'food_factory_district', NULL,
  ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations'),
  '{"mode":"byParam","byParam":{"xParam":"district"}}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局 / 新北市政府衛生局',
  '雙北食品工廠行政區統計',
  '統計臺北市與新北市各行政區的合法食品工廠登記數量，地圖顯示每座工廠的實際位置（藍色：臺北市，橘色：新北市）。',
  '了解雙北食品製造業的地理分布，協助食安稽查資源配置規劃。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, count AS data
FROM (VALUES
  ('內湖區',21),('南港區',16),('士林區',9),('大同區',5),('萬華區',5),
  ('北投區',4),('文山區',3),('中山區',3),('松山區',1),('中正區',1),
  ('中和區',169),('新莊區',149),('樹林區',127),('三重區',126),('汐止區',109),
  ('新店區',98),('土城區',91),('五股區',83),('板橋區',48),('三峽區',39),
  ('淡水區',37),('深坑區',26),('鶯歌區',25),('八里區',21),('林口區',18),
  ('瑞芳區',17),('泰山區',17),('蘆洲區',15),('三芝區',6),('永和區',2),
  ('坪林區',2),('石門區',2),('金山區',1),('石碇區',1)
) AS t(district, count)
ORDER BY count DESC$SQL$,
  NULL, 'metrotaipei'
) ON CONFLICT DO NOTHING;

-- 301 food_factory_district — taipei (10 區)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'food_factory_district', NULL,
  ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations_taipei'),
  '{"mode":"byParam","byParam":{"xParam":"district"}}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局',
  '臺北市食品工廠行政區統計',
  '統計臺北市各行政區的合法食品工廠登記數量，地圖顯示每座工廠的實際位置。',
  '了解臺北市食品製造業的地理分布，協助食安稽查資源配置規劃。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, count AS data
FROM (VALUES
  ('內湖區',21),('南港區',16),('士林區',9),('大同區',5),('萬華區',5),
  ('北投區',4),('文山區',3),('中山區',3),('松山區',1),('中正區',1)
) AS t(district, count)
ORDER BY count DESC$SQL$,
  NULL, 'taipei'
) ON CONFLICT DO NOTHING;

-- 302 food_inspection_failures — metrotaipei (41 區)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'food_inspection_failures', NULL,
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
) ON CONFLICT DO NOTHING;

-- 302 food_inspection_failures — taipei (12 區)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'food_inspection_failures', NULL,
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
) ON CONFLICT DO NOTHING;

-- 303 rfsrai_index — metrotaipei (41 區, ×100 updated data)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'rfsrai_index', NULL, NULL, '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局 / 新北市政府衛生局',
  '雙北 RFSRAI 區域食品安全風險評估指標',
  'RFSRAI（Regional Food Safety Risk Assessment Index）區域食品安全風險評估指標，數值 ×100 顯示。計算公式：RFSRAI = 0.45H + 0.3E + 0.25S − 0.05M。H 風險基礎值（權重 0.45）：各區食品抽驗標準差，離群值越高代表該區越不穩定。E 學生暴露量（權重 0.3）：各區學校數占雙北全區比例，學校越密集出事時受影響人數越多。S 物流風險（權重 0.25）：供應商集中度比例，集中度越高一旦廠商出問題全區皆受波及。M 管理扣分（權重 −0.05）：通過二級品管驗證之業者比例，自主管理越好整體風險越低。',
  '識別雙北高風險行政區，協助衛生局優先配置稽查資源，指數越高代表該區食品安全管理優先程度越高。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, score AS data
FROM (VALUES
  ('大安區',78.14),('中山區',72.13),('板橋區',69.52),('士林區',63.29),
  ('中正區',50.69),('北投區',50.46),('松山區',47.87),('萬華區',47.79),
  ('文山區',45.11),('新莊區',41.76),('新店區',38.38),('信義區',35.25),
  ('大同區',34.76),('內湖區',34.44),('三重區',31.71),('中和區',29.66),
  ('樹林區',22.08),('三峽區',18.28),('蘆洲區',17.78),('汐止區',16.98),
  ('貢寮區',16.59),('石門區',16.43),('淡水區',16.38),('永和區',16.19),
  ('烏來區',15.70),('萬里區',14.19),('平溪區',14.15),('土城區',13.52),
  ('南港區',13.30),('瑞芳區',13.23),('林口區',11.94),('雙溪區',10.74),
  ('金山區',10.70),('深坑區',8.82),('石碇區',8.59),('五股區',7.93),
  ('三芝區',7.92),('鶯歌區',7.87),('坪林區',5.89),('八里區',5.39),
  ('泰山區',4.87)
) AS t(district, score)
ORDER BY score DESC$SQL$,
  NULL, 'metrotaipei'
) ON CONFLICT DO NOTHING;

-- 303 rfsrai_index — taipei (12 區, ×100 updated data)
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
) VALUES (
  'rfsrai_index', NULL, NULL, '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局',
  '臺北市 RFSRAI 區域食品安全風險評估指標',
  'RFSRAI（Regional Food Safety Risk Assessment Index）區域食品安全風險評估指標，數值 ×100 顯示。計算公式：RFSRAI = 0.45H + 0.3E + 0.25S − 0.05M。H 風險基礎值（權重 0.45）：各區食品抽驗標準差，離群值越高代表該區越不穩定。E 學生暴露量（權重 0.3）：各區學校數占雙北全區比例，學校越密集出事時受影響人數越多。S 物流風險（權重 0.25）：供應商集中度比例，集中度越高一旦廠商出問題全區皆受波及。M 管理扣分（權重 −0.05）：通過二級品管驗證之業者比例，自主管理越好整體風險越低。',
  '識別臺北市高風險行政區，協助衛生局優先配置稽查資源。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, score AS data
FROM (VALUES
  ('大安區',78.14),('中山區',72.13),('士林區',63.29),('中正區',50.69),
  ('北投區',50.46),('松山區',47.87),('萬華區',47.79),('文山區',45.11),
  ('信義區',35.25),('大同區',34.76),('內湖區',34.44),('南港區',13.30)
) AS t(district, score)
ORDER BY score DESC$SQL$,
  NULL, 'taipei'
) ON CONFLICT DO NOTHING;

-- ── fix sequence ──────────────────────────────────────────────────────────────
SELECT pg_catalog.setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
SELECT pg_catalog.setval('public.dashboards_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.dashboards), true);

COMMIT;
