-- Seed: 食安健康 dashboard + 學校供餐供應鏈 SankeyChart component
-- Target DB: postgres-manager

-- 1. Component chart config
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'school_food_supply_chain',
    '{}',
    '{SankeyChart}',
    '次'
)
ON CONFLICT (index) DO NOTHING;

-- 2. Component metadata
INSERT INTO public.components (id, index, name)
VALUES (
    300,
    'school_food_supply_chain',
    '雙北學校供餐供應鏈'
)
ON CONFLICT (id) DO NOTHING;

-- 3. Query chart config (static — data loaded from frontend JSON)
--    Returns empty dataset; SankeyChart ignores series and uses static JSON.
INSERT INTO public.query_charts (
    index,
    history_config,
    map_config_ids,
    map_filter,
    time_from,
    time_to,
    update_freq,
    update_freq_unit,
    source,
    short_desc,
    long_desc,
    use_case,
    links,
    contributors,
    created_at,
    updated_at,
    query_type,
    query_chart,
    query_history,
    city
)
VALUES (
    'school_food_supply_chain',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    0,
    NULL,
    '教育局',
    '雙北中小學及高中職供餐食材供應鏈（上游供應商 → 中游供餐業者 → 下游學校）',
    '本圖以桑基圖呈現雙北地區（臺北市、新北市）中小學及高中職學校的供餐供應鏈結構。上游為食材及調味料供應商，中游為各供餐業者，下游為學校。連結寬度代表供貨次數，顯示各供應商與供餐業者之間的合作密度，以及供餐業者服務學校的頻率。可依市縣篩選查看臺北市或新北市的供應鏈分布。',
    '適用於食品安全稽查、供應鏈風險評估及教育餐飲管理。透過視覺化供應鏈關係，可快速識別高風險供應商（供貨次數異常集中）、單一業者依賴風險，以及跨市供應商的分布情形，支援食安政策制定與應急追溯。',
    '{https://data.taipei/dataset/detail?id=school-food-supply}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'static',
    'static',
    NULL,
    'metrotaipei'
)
ON CONFLICT DO NOTHING;

-- 4. Dashboard: 食安健康
INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    400,
    'food_safety_health',
    '食安健康',
    '{300}',
    'restaurant',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 5. Link dashboard to metrotaipei group (group_id = 3 = 雙北)
INSERT INTO public.dashboard_groups (dashboard_id, group_id)
VALUES (400, 3)
ON CONFLICT DO NOTHING;
