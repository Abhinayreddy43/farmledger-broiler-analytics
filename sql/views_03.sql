-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/views_03.sql
-- Step 4: two views.
--   v_batch_checks : does every batch add up? (the data quality check)
--   v_batch_kpis   : one clean row per batch with the key numbers
--
-- A view is a saved query. It stores no data of its own: every time you
-- read it, PostgreSQL runs the query on the current tables. So when a new
-- batch is loaded, both views include it automatically.
--
-- Safe to run twice (CREATE OR REPLACE VIEW).
-- Run 'create_tables_01' and 'load_data_02' first.
-- =====================================================================

SET search_path TO farmledger;


-- ---------------------------------------------------------------------
-- 1. v_batch_checks
-- Each check is TRUE when the numbers add up, FALSE when something is off.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_checks AS
WITH payout_total AS (            -- payout lines added up with their +1 / -1 signs
    SELECT p.batch_no,
           SUM(p.amount * i.effect_sign) AS calc_net_payable
    FROM fact_payout_line p
    JOIN dim_payout_item i USING (payout_item_id)
    GROUP BY p.batch_no
),
cost_total AS (                   -- the four cost lines added up
    SELECT batch_no,
           SUM(amount) AS calc_total_cost
    FROM fact_cost_line
    GROUP BY batch_no
)
SELECT
    f.batch_no,
    pt.calc_net_payable,
    f.net_payable                                              AS printed_net_payable,
    ROUND(pt.calc_net_payable - f.net_payable, 2)              AS net_difference,
    ABS(pt.calc_net_payable - f.net_payable) <= 1              AS net_ok,       -- 1 rupee rounding allowed
    ABS(f.feed_issued_kg + f.feed_in_kg - f.feed_out_kg
        - f.material_return_kg - f.total_feed_consumption_kg) < 0.5
                                                               AS feed_ok,
    ABS(ct.calc_total_cost - f.production_cost_total) <= 1     AS cost_ok,
    (f.housed_chicks - f.mortality + f.excess_birds
        - f.shortage_birds) = f.sold_birds                     AS birds_ok,
    ABS(f.mortality * 100.0 / f.housed_chicks - f.total_mort_pct) <= 0.01
                                                               AS mortality_pct_ok,
    ABS(f.total_feed_consumption_kg / f.birds_weight_kg - f.fcr) <= 0.01
                                                               AS fcr_ok
FROM fact_batch f
LEFT JOIN payout_total pt USING (batch_no)
LEFT JOIN cost_total   ct USING (batch_no);

-- all_ok is added in a second view so the first one stays easy to read
CREATE OR REPLACE VIEW v_batch_checks_summary AS
SELECT *,
       COALESCE(net_ok AND feed_ok AND cost_ok AND birds_ok
                AND mortality_pct_ok AND fcr_ok, FALSE) AS all_ok
FROM v_batch_checks;


-- ---------------------------------------------------------------------
-- 2. v_batch_kpis
-- One row per batch: the numbers the dashboard and the business
-- questions need. Money is in rupees.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_kpis AS
WITH payout_groups AS (           -- payout lines grouped by what kind of line they are
    SELECT p.batch_no,
           SUM(p.amount) FILTER (WHERE i.category = 'earning')             AS gross_earnings,
           SUM(p.amount) FILTER (WHERE i.category = 'performance_penalty') AS performance_penalties,
           SUM(p.amount) FILTER (WHERE i.category = 'bird_deduction')      AS bird_deductions,
           SUM(p.amount) FILTER (WHERE i.category = 'other_deduction')     AS company_purchases_and_other,
           SUM(p.amount) FILTER (WHERE i.category = 'tax')                 AS tds
    FROM fact_payout_line p
    JOIN dim_payout_item i USING (payout_item_id)
    GROUP BY p.batch_no
)
SELECT
    b.batch_no,
    b.housed_date,
    b.liquid_date,
    (b.liquid_date - b.housed_date)                       AS cycle_days,
    s.scheme_name,
    b.grade,
    -- performance
    f.housed_chicks,
    f.mortality,
    f.sold_birds,
    ROUND(f.mortality * 100.0 / f.housed_chicks, 2)       AS mortality_pct,
    f.mort_up_to_30_pct                                   AS early_mortality_pct,   -- first 30 days
    f.mort_after_30_pct                                   AS late_mortality_pct,    -- after day 30
    ROUND(f.mort_after_30_pct * 100.0
          / NULLIF(f.total_mort_pct, 0), 1)               AS share_of_deaths_after_30_pct,
    f.fcr,
    f.avg_weight_kg,
    f.eef,
    -- cost
    f.production_cost_total,
    ROUND(f.production_cost_total / f.birds_weight_kg, 2) AS production_cost_per_kg,
    -- payout
    f.net_payable,
    ROUND(f.net_payable / f.sold_birds, 2)                AS net_payable_per_bird,
    ROUND(f.net_payable / f.birds_weight_kg, 2)           AS net_payable_per_kg,
    f.gc_per_kg,
    -- what reduced the payout
    g.gross_earnings,
    g.performance_penalties,
    g.bird_deductions,
    g.company_purchases_and_other,
    g.tds,
    -- reported by the farmer
    EXISTS (SELECT 1 FROM batch_event e
            WHERE e.batch_no = b.batch_no
              AND e.event_type = 'Disease')               AS disease_reported
FROM dim_batch b
JOIN dim_scheme   s USING (scheme_id)
JOIN fact_batch   f USING (batch_no)
LEFT JOIN payout_groups g USING (batch_no);


-- ---------------------------------------------------------------------
-- 3. LOOK AT THE RESULTS
-- ---------------------------------------------------------------------
-- A. Every batch should show TRUE in all_ok
SELECT batch_no, net_difference, net_ok, feed_ok, cost_ok, birds_ok,
       mortality_pct_ok, fcr_ok, all_ok
FROM v_batch_checks_summary
ORDER BY batch_no;

-- B. The KPI table
SELECT * FROM v_batch_kpis ORDER BY batch_no;
