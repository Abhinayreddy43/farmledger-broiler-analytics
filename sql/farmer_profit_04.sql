-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/farmer_profit_04.sql
-- Step 5: what the farmer really earns per batch.
--
--   farmer_profit = net payable  -  own costs  +  manure income
--
-- Own costs are the costs NOT on the growing charge statement (newspaper,
-- charcoal, rice husk, soil, labour, electricity). Chicks, feed, medicines
-- and vaccines are paid by the company and are already inside the statement.
--
-- Every figure comes from the farm_assumption table (your father's rounded
-- numbers), so changing a value there changes the profit; no SQL edit needed.
--
-- Safe to run twice. Run 'views_03' first.
-- =====================================================================

SET search_path TO farmledger;

CREATE OR REPLACE VIEW v_farmer_profit AS
WITH a AS (                          -- the assumptions we need, one row
    SELECT
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'newspaper')  AS newspaper,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'charcoal')   AS charcoal,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'rice_husk')  AS rice_husk,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'soil')       AS soil,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'labour')     AS labour,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'electricity'
                                 AND applies_to = 'monsoon and winter')                   AS electricity_normal,
        MAX(value_num) FILTER (WHERE category = 'cost_per_batch' AND item = 'electricity'
                                 AND applies_to = 'summer')                               AS electricity_summer,
        MAX(value_num) FILTER (WHERE category = 'manure' AND item = 'tractor_loads_per_batch') AS manure_loads,
        MAX(value_num) FILTER (WHERE category = 'manure' AND item = 'value_per_load')     AS manure_value_per_load
    FROM farm_assumption
),
batch_days AS (                      -- how many days of each batch fall in summer?
    SELECT b.batch_no,
           COUNT(*)                                                    AS total_days,
           COUNT(*) FILTER (WHERE EXTRACT(MONTH FROM g.d) IN (3, 4, 5, 6)) AS summer_days   -- summer = Mar to Jun (father's definition)
    FROM dim_batch b
    CROSS JOIN LATERAL generate_series(b.housed_date::timestamp,
                                       b.liquid_date::timestamp,
                                       interval '1 day') AS g(d)
    GROUP BY b.batch_no
),
costs AS (
    SELECT f.batch_no,
           f.net_payable,
           f.sold_birds,
           d.summer_days::numeric / d.total_days                       AS summer_day_share,
           -- electricity: normal bill, rising towards the summer bill as more days fall in summer
           ROUND(a.electricity_normal
                 + (a.electricity_summer - a.electricity_normal) * d.summer_days / d.total_days, 0) AS electricity_cost,
           a.newspaper, a.charcoal, a.rice_husk, a.soil, a.labour,
           a.manure_loads * a.manure_value_per_load                    AS manure_income
    FROM fact_batch f
    JOIN batch_days d USING (batch_no)
    CROSS JOIN a
)
SELECT
    c.batch_no,
    c.net_payable,
    ROUND(c.summer_day_share, 2)                                       AS summer_day_share,
    c.newspaper, c.charcoal, c.rice_husk, c.soil, c.labour, c.electricity_cost,
    (c.newspaper + c.charcoal + c.rice_husk + c.soil + c.labour + c.electricity_cost) AS total_own_costs,
    c.manure_income,
    c.net_payable
        - (c.newspaper + c.charcoal + c.rice_husk + c.soil + c.labour + c.electricity_cost)
        + c.manure_income                                              AS farmer_profit,
    ROUND((c.net_payable
        - (c.newspaper + c.charcoal + c.rice_husk + c.soil + c.labour + c.electricity_cost)
        + c.manure_income) / c.sold_birds, 2)                          AS profit_per_bird,
    -- the net payable needed just to break even
    (c.newspaper + c.charcoal + c.rice_husk + c.soil + c.labour + c.electricity_cost)
        - c.manure_income                                              AS break_even_net_payable,
    -- how much of the own costs the manure income pays for
    ROUND(c.manure_income * 100.0
        / (c.newspaper + c.charcoal + c.rice_husk + c.soil + c.labour + c.electricity_cost), 1) AS manure_covers_pct_of_costs,
    k.mortality_pct,
    k.disease_reported
FROM costs c
JOIN v_batch_kpis k USING (batch_no);


-- ---------------------------------------------------------------------
-- LOOK AT THE RESULTS
-- ---------------------------------------------------------------------
-- A. Profit per batch
SELECT batch_no, net_payable, total_own_costs, manure_income, farmer_profit,
       break_even_net_payable, manure_covers_pct_of_costs, disease_reported
FROM v_farmer_profit
ORDER BY batch_no;

-- B. Disease-reported batches compared with the others
SELECT disease_reported,
       COUNT(*)                          AS batches,
       ROUND(AVG(mortality_pct), 1)      AS avg_mortality_pct,
       ROUND(AVG(net_payable), 0)        AS avg_net_payable,
       ROUND(AVG(farmer_profit), 0)      AS avg_farmer_profit
FROM v_farmer_profit
GROUP BY disease_reported;
