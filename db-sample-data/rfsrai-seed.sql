-- RFSRAI component seed
-- Regional Food Safety Risk Assessment Index (區域食品安全風險評估指標)
-- Formula: RFSRAI = 0.45H + 0.3E + 0.25S - 0.05M  (displayed ×100)
-- Target DB: postgres-manager
-- Component id=303, dashboard id=400, no map layer

BEGIN;

-- ── 1. component_charts ───────────────────────────────────────────────────────
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
  'rfsrai_index',
  '{"#dc2626","#f87171","#fca5a5"}',
  '{TreemapChart,DistrictChart}',
  'pts'
)
ON CONFLICT (index) DO NOTHING;

-- ── 2. components ─────────────────────────────────────────────────────────────
INSERT INTO public.components (id, index, name)
VALUES (303, 'rfsrai_index', '區域食品安全風險評估指標 (RFSRAI)')
ON CONFLICT (id) DO NOTHING;

-- ── 3. query_charts: metrotaipei (all 41 districts, sorted DESC) ──────────────
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES (
  'rfsrai_index',
  NULL,
  NULL,
  '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局 / 新北市政府衛生局',
  '雙北 RFSRAI 區域食品安全風險評估指標',
  'RFSRAI（Regional Food Safety Risk Assessment Index）區域食品安全風險評估指標，數值 ×100 顯示。計算公式：RFSRAI = 0.45H + 0.3E + 0.25S − 0.05M。H 風險基礎值（權重 0.45）：各區食品抽驗標準差，離群值越高代表該區越不穩定。E 學生暴露量（權重 0.3）：各區學校數占雙北全區比例，學校越密集出事時受影響人數越多。S 物流風險（權重 0.25）：供應商集中度比例，集中度越高一旦廠商出問題全區皆受波及。M 管理扣分（權重 −0.05）：通過二級品管驗證之業者比例，自主管理越好整體風險越低。',
  '識別雙北高風險行政區，協助衛生局優先配置稽查資源，指數越高代表該區食品安全管理優先程度越高。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, score AS data
FROM (VALUES
  ('烏來區',22.24),('石門區',21.47),('貢寮區',19.01),('平溪區',18.31),
  ('萬里區',16.59),('雙溪區',12.72),('石碇區',9.74),('三芝區',9.70),
  ('松山區',9.22),('坪林區',8.68),('金山區',8.37),('大安區',8.21),
  ('瑞芳區',7.42),('板橋區',7.38),('北投區',7.36),('中山區',7.02),
  ('士林區',7.00),('新店區',6.70),('南港區',6.62),('大同區',6.48),
  ('淡水區',6.44),('深坑區',6.41),('萬華區',6.07),('信義區',5.89),
  ('中正區',5.43),('土城區',5.35),('新莊區',5.22),('文山區',5.13),
  ('五股區',5.10),('樹林區',5.05),('內湖區',4.78),('八里區',4.59),
  ('三峽區',4.41),('三重區',4.16),('中和區',4.13),('林口區',3.92),
  ('蘆洲區',3.88),('汐止區',3.76),('鶯歌區',3.63),('永和區',3.29),
  ('泰山區',2.99)
) AS t(district, score)
ORDER BY score DESC$SQL$,
  NULL, 'metrotaipei'
)
ON CONFLICT DO NOTHING;

-- ── 4. query_charts: taipei (12 districts only) ───────────────────────────────
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES (
  'rfsrai_index',
  NULL,
  NULL,
  '{}',
  'static', NULL, 0, NULL,
  '臺北市政府衛生局',
  '臺北市 RFSRAI 區域食品安全風險評估指標',
  'RFSRAI（Regional Food Safety Risk Assessment Index）區域食品安全風險評估指標，數值 ×100 顯示。計算公式：RFSRAI = 0.45H + 0.3E + 0.25S − 0.05M。H 風險基礎值（權重 0.45）：各區食品抽驗標準差，離群值越高代表該區越不穩定。E 學生暴露量（權重 0.3）：各區學校數占雙北全區比例，學校越密集出事時受影響人數越多。S 物流風險（權重 0.25）：供應商集中度比例，集中度越高一旦廠商出問題全區皆受波及。M 管理扣分（權重 −0.05）：通過二級品管驗證之業者比例，自主管理越好整體風險越低。',
  '識別臺北市高風險行政區，協助衛生局優先配置稽查資源。',
  '{}', '{}', NOW(), NOW(),
  'two_d',
  $SQL$SELECT district AS x_axis, score AS data
FROM (VALUES
  ('松山區',9.22),('大安區',8.21),('北投區',7.36),('中山區',7.02),
  ('士林區',7.00),('南港區',6.62),('大同區',6.48),('萬華區',6.07),
  ('信義區',5.89),('中正區',5.43),('文山區',5.13),('內湖區',4.78)
) AS t(district, score)
ORDER BY score DESC$SQL$,
  NULL, 'taipei'
)
ON CONFLICT DO NOTHING;

-- ── 5. add component 303 to dashboard 400 ────────────────────────────────────
UPDATE public.dashboards
SET components = array_append(components, 303)
WHERE id = 400
  AND NOT (components @> ARRAY[303]);

COMMIT;
