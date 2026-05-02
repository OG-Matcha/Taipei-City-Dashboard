-- Fix: ensure exactly ONE component 301 in dashboard,
-- and correct city-specific queries (taipei vs metrotaipei)
-- Target DB: postgres-manager

BEGIN;

-- ── 1. Fix dashboard: exactly [300, 301] ──────────────────────────────────────
UPDATE public.dashboards
SET components = ARRAY[300, 301]
WHERE id = 400;

-- ── 2. Drop all existing food_factory_district query_chart rows ───────────────
DELETE FROM public.query_charts WHERE index = 'food_factory_district';

-- ── 3. Re-insert correct rows: metrotaipei (全部) + taipei (臺北市 only) ────────
INSERT INTO public.query_charts (
  index, history_config, map_config_ids, map_filter,
  time_from, time_to, update_freq, update_freq_unit,
  source, short_desc, long_desc, use_case,
  links, contributors, created_at, updated_at,
  query_type, query_chart, query_history, city
)
VALUES
  -- 雙北 (metrotaipei): all 34 districts
  (
    'food_factory_district', NULL,
    ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations'),
    '{}',
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
  ),
  -- 臺北市 (taipei): Taipei's 10 districts only
  (
    'food_factory_district', NULL,
    ARRAY(SELECT id FROM public.component_maps WHERE index = 'food_factory_locations'),
    '{}',
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
  );

COMMIT;
