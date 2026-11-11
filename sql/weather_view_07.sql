-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/weather_view_07.sql
-- Step 9: the weather of each batch's cycle, one row per batch.
--
-- Joins the daily weather (fact_weather_day) to the days of each batch
-- (v_batch_days) and summarises it: temperature, hot days, humidity, rain.
--
-- Safe to run twice. Run 'calendar_05' and 'weather_table_06' first, and
-- make sure the n8n weather workflow has loaded the data.
-- =====================================================================

SET search_path TO farmledger;

-- ---------------------------------------------------------------------
-- 1. Two weather thresholds, kept in the assumptions table
-- (changing a value here changes the view; no SQL edit needed)
-- ---------------------------------------------------------------------
INSERT INTO farm_assumption (category, item, value_num, unit, applies_to, confidence) VALUES
    ('weather', 'heat_stress_threshold_c', 35, 'degC (a day hotter than this counts as a hot day)', 'all', 'medium'),
    ('weather', 'rainy_day_min_mm',         1, 'mm (a day with at least this much rain counts as rainy)', 'all', 'medium')
ON CONFLICT (category, item, applies_to) DO NOTHING;


-- ---------------------------------------------------------------------
-- 2. v_batch_weather
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_weather AS
WITH a AS (                           -- the two thresholds, as one row
    SELECT
        MAX(value_num) FILTER (WHERE category = 'weather' AND item = 'heat_stress_threshold_c') AS heat_c,
        MAX(value_num) FILTER (WHERE category = 'weather' AND item = 'rainy_day_min_mm')        AS rainy_mm
    FROM farm_assumption
)
SELECT
    bd.batch_no,
    COUNT(*)                                                          AS days_in_cycle,
    COUNT(w.weather_date)                                             AS days_with_weather,   -- should equal days_in_cycle
    ROUND(AVG(w.temp_mean_c), 1)                                      AS avg_temp_mean_c,
    ROUND(AVG(w.temp_max_c), 1)                                       AS avg_temp_max_c,
    MAX(w.temp_max_c)                                                 AS hottest_day_c,
    COUNT(*) FILTER (WHERE w.temp_max_c > a.heat_c)                   AS hot_days,
    COUNT(*) FILTER (WHERE w.temp_max_c > a.heat_c
                       AND bd.day_of_cycle > 30)                      AS hot_days_after_30,   -- after day 30 of the cycle
    ROUND(AVG(w.humidity_mean_pct), 1)                                AS avg_humidity_pct,
    ROUND(SUM(w.precipitation_mm), 1)                                 AS total_rain_mm,
    COUNT(*) FILTER (WHERE w.precipitation_mm >= a.rainy_mm)          AS rainy_days
FROM v_batch_days bd
LEFT JOIN fact_weather_day w ON w.weather_date = bd.date_key
CROSS JOIN a
GROUP BY bd.batch_no;


-- ---------------------------------------------------------------------
-- 3. LOOK AT THE RESULTS
-- ---------------------------------------------------------------------
-- A. Weather per batch, next to mortality.
--    First check: days_with_weather must equal days_in_cycle on every row.
SELECT w.batch_no,
       k.mortality_pct,
       k.disease_reported,
       w.days_in_cycle, w.days_with_weather,
       w.avg_temp_mean_c, w.hot_days, w.hot_days_after_30,
       w.avg_humidity_pct, w.total_rain_mm, w.rainy_days
FROM v_batch_weather w
JOIN v_batch_kpis k USING (batch_no)
ORDER BY w.batch_no;

-- B. Disease-reported batches against the others (only 7 batches:
--    a pattern to look at, not proof of a cause)
SELECT k.disease_reported,
       COUNT(*)                          AS batches,
       ROUND(AVG(w.avg_temp_mean_c), 1)  AS avg_temp_c,
       ROUND(AVG(w.hot_days), 1)         AS avg_hot_days,
       ROUND(AVG(w.avg_humidity_pct), 1) AS avg_humidity_pct,
       ROUND(AVG(w.total_rain_mm), 0)    AS avg_rain_mm
FROM v_batch_weather w
JOIN v_batch_kpis k USING (batch_no)
GROUP BY k.disease_reported;
