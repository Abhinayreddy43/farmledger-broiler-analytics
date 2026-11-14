-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/batch_analysis_08.sql
-- Step 10: two views made for the Power BI report.
--
--   v_batch_analysis   : ONE wide row per batch with everything together
--                        (performance, payout, deductions, profit, weather,
--                         season, data quality)
--   v_payout_waterfall : one row per batch per payout line, with the sign
--                        applied (for the payout waterfall chart)
--
-- They only combine the views we already built, so there are no new
-- calculations to trust. When a new batch is loaded, both include it.
--
-- Safe to run twice. Run files 01 to 07 first.
-- =====================================================================

SET search_path TO farmledger;

-- ---------------------------------------------------------------------
-- 1. v_batch_analysis
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_analysis AS
WITH season_days AS (                 -- how many days of each batch fall in each season
    SELECT batch_no,
           COUNT(*) FILTER (WHERE season = 'summer')  AS summer_days,
           COUNT(*) FILTER (WHERE season = 'monsoon') AS monsoon_days,
           COUNT(*) FILTER (WHERE season = 'winter')  AS winter_days
    FROM v_batch_days
    GROUP BY batch_no
)
SELECT
    -- identity and dates
    k.batch_no,
    k.housed_date,
    k.liquid_date,
    k.cycle_days,
    k.scheme_name,
    k.grade,
    -- season
    s.summer_days,
    s.monsoon_days,
    s.winter_days,
    CASE WHEN s.summer_days  >= s.monsoon_days AND s.summer_days >= s.winter_days THEN 'summer'
         WHEN s.monsoon_days >= s.winter_days                                     THEN 'monsoon'
         ELSE 'winter' END                                           AS main_season,
    ((s.summer_days > 0)::int + (s.monsoon_days > 0)::int + (s.winter_days > 0)::int) > 1
                                                                     AS crosses_seasons,
    -- performance
    k.housed_chicks,
    k.mortality,
    k.sold_birds,
    k.mortality_pct,
    k.early_mortality_pct,
    k.late_mortality_pct,
    k.share_of_deaths_after_30_pct,
    k.fcr,
    k.avg_weight_kg,
    k.eef,
    k.disease_reported,
    -- company costs and payout
    k.production_cost_total,
    k.production_cost_per_kg,
    k.gc_per_kg,
    k.gross_earnings,
    k.performance_penalties,
    k.bird_deductions,
    k.company_purchases_and_other,
    k.tds,
    k.net_payable,
    k.net_payable_per_bird,
    k.net_payable_per_kg,
    -- the farmer's own side
    p.electricity_cost,
    p.total_own_costs,
    p.manure_income,
    p.farmer_profit,
    p.profit_per_bird,
    (p.farmer_profit < 0)                                            AS is_loss_making,
    p.break_even_net_payable,
    p.manure_covers_pct_of_costs,
    -- weather during the cycle
    w.avg_temp_mean_c,
    w.hot_days,
    w.hot_days_after_30,
    w.avg_humidity_pct,
    w.total_rain_mm,
    w.rainy_days,
    -- data quality
    c.all_ok                                                         AS data_checks_ok
FROM v_batch_kpis k
LEFT JOIN season_days            s USING (batch_no)
LEFT JOIN v_farmer_profit        p USING (batch_no)
LEFT JOIN v_batch_weather        w USING (batch_no)
LEFT JOIN v_batch_checks_summary c USING (batch_no);


-- ---------------------------------------------------------------------
-- 2. v_payout_waterfall
-- amount is always positive; signed_amount carries the + or - sign.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_payout_waterfall AS
SELECT p.batch_no,
       i.display_order,
       i.payout_item_name,
       i.category,
       i.effect_sign,
       p.amount,
       p.amount * i.effect_sign AS signed_amount,
       p.qty_birds,
       p.qty_kg,
       p.description
FROM fact_payout_line p
JOIN dim_payout_item i USING (payout_item_id);


-- ---------------------------------------------------------------------
-- 3. CHECKS
-- ---------------------------------------------------------------------
-- A. One row per batch, and every data check true. Expected: 7 rows, all true
SELECT COUNT(*) AS batches, BOOL_AND(data_checks_ok) AS all_data_checks_ok
FROM v_batch_analysis;

-- B. The wide table, the main columns
SELECT batch_no, main_season, crosses_seasons, mortality_pct, fcr,
       net_payable, total_own_costs, manure_income, farmer_profit,
       is_loss_making, hot_days, total_rain_mm
FROM v_batch_analysis
ORDER BY batch_no;

-- C. The waterfall of one batch adds up to its net payable (batch 42 here)
--    Expected: 136627 (rounding under 1 rupee)
SELECT SUM(signed_amount) AS calculated_net
FROM v_payout_waterfall
WHERE batch_no = 42;
