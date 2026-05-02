-- Cleanup + rebuild food factory component
-- Removes wrong component 302, fixes duplicate dashboard entries,
-- then upgrades component 301 to DistrictChart + two_d query
-- Target DB: postgres-manager

BEGIN;

-- ── Remove wrong component 302 ────────────────────────────────────────────────
DELETE FROM public.query_charts  WHERE index = 'food_factory_map';
DELETE FROM public.components    WHERE id = 302;
DELETE FROM public.component_charts WHERE index = 'food_factory_map';

-- ── Fix dashboard 400: rebuild components array with exactly {300, 301} ───────
UPDATE public.dashboards
SET components = ARRAY(
  SELECT DISTINCT unnest(components)
  FROM public.dashboards
  WHERE id = 400
  -- keep 300 (sankey) and 301 (food factory), drop 302 and any duplicate 301
  AND components && ARRAY[300, 301]
)
WHERE id = 400;

-- Force correct array (removes duplicates and 302)
UPDATE public.dashboards
SET components = ARRAY[300, 301]
WHERE id = 400;

-- ── Upgrade component_charts 301: DistrictChart + BarChart ────────────────────
UPDATE public.component_charts
SET types = '{DistrictChart,BarChart}',
    color = '{"#5b9fe8","#f59e0b","#6b8fa3"}'
WHERE index = 'food_factory_district';

-- ── Upgrade query_charts 301: two_d with embedded VALUES ─────────────────────
-- SQL runs on postgres-data (DBDashboard); VALUES needs no real tables.
-- Includes all 雙北 districts. DistrictChart will color-code by count.
UPDATE public.query_charts
SET query_type  = 'two_d',
    query_chart = $SQL$
SELECT district AS x_axis, count AS data
FROM (VALUES
  ('內湖區',21),('南港區',16),('士林區',9),('大同區',5),('萬華區',5),
  ('北投區',4),('文山區',3),('中山區',3),('松山區',1),('中正區',1),
  ('中和區',169),('新莊區',149),('樹林區',127),('三重區',126),('汐止區',109),
  ('新店區',98),('土城區',91),('五股區',83),('板橋區',48),('三峽區',39),
  ('淡水區',37),('深坑區',26),('鶯歌區',25),('八里區',21),('林口區',18),
  ('瑞芳區',17),('泰山區',17),('蘆洲區',15),('三芝區',6),('永和區',2),
  ('坪林區',2),('石門區',2),('金山區',1),('石碇區',1)
) AS t(district, count)
ORDER BY count DESC
$SQL$
WHERE index = 'food_factory_district';

COMMIT;
