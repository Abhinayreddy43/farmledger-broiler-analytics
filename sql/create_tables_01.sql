-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/create_tables_01.sql
-- Step 2: create the schema (tables) and the small reference tables.
--
-- How to run (pick one):
--   pgAdmin : open Query Tool on your database, open this file, press F5
--
-- Safe to run twice: every table uses IF NOT EXISTS.
-- To start completely over (this DELETES everything), run this line first:
--   DROP SCHEMA IF EXISTS farmledger CASCADE;
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS farmledger;   -- a schema is a folder inside the database
SET search_path TO farmledger;            -- from here on, tables are created inside it


-- ---------------------------------------------------------------------
-- 1. REFERENCE TABLES (small lists that rarely change)
-- ---------------------------------------------------------------------

-- The contract scheme printed on each statement (the rate can differ by scheme).
CREATE TABLE IF NOT EXISTS dim_scheme (
    scheme_id           SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scheme_name         TEXT          NOT NULL UNIQUE,
    std_growing_charge  NUMERIC(5,2)  NOT NULL CHECK (std_growing_charge > 0)
);

-- The four cost items in the COST DETAILS block.
CREATE TABLE IF NOT EXISTS dim_cost_item (
    cost_item_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cost_item_name  TEXT      NOT NULL UNIQUE,
    display_order   SMALLINT  NOT NULL
);

-- The 13 money lines of the payout block.
-- effect_sign lives HERE and only here: +1 adds to the payout, -1 reduces it.
-- This way the sign can never be mistyped in the data rows.
CREATE TABLE IF NOT EXISTS dim_payout_item (
    payout_item_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payout_item_name  TEXT      NOT NULL UNIQUE,
    category          TEXT      NOT NULL,
    effect_sign       SMALLINT  NOT NULL CHECK (effect_sign IN (1, -1)),
    display_order     SMALLINT  NOT NULL,
    description       TEXT
);


-- ---------------------------------------------------------------------
-- 2. BATCH TABLES
-- ---------------------------------------------------------------------

-- One row per batch: who, where, when (descriptive information).
CREATE TABLE IF NOT EXISTS dim_batch (
    batch_no        INTEGER   PRIMARY KEY,
    farm_code       TEXT      NOT NULL,
    scheme_id       SMALLINT  NOT NULL REFERENCES dim_scheme (scheme_id),
    book_num        INTEGER,
    grade           CHAR(1)   CHECK (grade IN ('A', 'B', 'C', 'D')),
    previous_grade  CHAR(1)   CHECK (previous_grade IN ('A', 'B', 'C', 'D')),   -- empty for the first batch
    area            TEXT,
    division        TEXT,
    housed_date     DATE      NOT NULL,
    liquid_date     DATE      NOT NULL,
    statement_date  DATE      NOT NULL,
    CHECK (liquid_date >= housed_date),
    CHECK (statement_date >= liquid_date)
);

-- One row per batch: the measured numbers (performance, feed, charges).
CREATE TABLE IF NOT EXISTS fact_batch (
    batch_no                   INTEGER PRIMARY KEY REFERENCES dim_batch (batch_no) ON DELETE CASCADE,
    housed_chicks              INTEGER       NOT NULL CHECK (housed_chicks > 0),
    mortality                  INTEGER       NOT NULL CHECK (mortality >= 0),
    sold_birds                 INTEGER       NOT NULL CHECK (sold_birds >= 0),
    birds_weight_kg            NUMERIC(10,1) NOT NULL CHECK (birds_weight_kg > 0),
    excess_birds               INTEGER       NOT NULL DEFAULT 0 CHECK (excess_birds >= 0),
    shortage_birds             INTEGER       NOT NULL DEFAULT 0 CHECK (shortage_birds >= 0),
    mort_up_to_30_pct          NUMERIC(5,2)  CHECK (mort_up_to_30_pct  BETWEEN 0 AND 100),
    mort_after_30_pct          NUMERIC(5,2)  CHECK (mort_after_30_pct  BETWEEN 0 AND 100),
    first_week_mort_pct        NUMERIC(5,2)  CHECK (first_week_mort_pct BETWEEN 0 AND 100),
    total_mort_pct             NUMERIC(5,2)  CHECK (total_mort_pct     BETWEEN 0 AND 100),
    fcr                        NUMERIC(5,2),
    cfcr                       NUMERIC(5,2),
    avg_weight_kg              NUMERIC(6,3),
    mean_age_days              NUMERIC(5,2),
    day_gain_gms               NUMERIC(6,2),
    eef                        NUMERIC(7,2),
    feed_issued_kg             INTEGER       NOT NULL CHECK (feed_issued_kg >= 0),
    feed_in_kg                 INTEGER       NOT NULL DEFAULT 0 CHECK (feed_in_kg >= 0),
    feed_out_kg                INTEGER       NOT NULL DEFAULT 0 CHECK (feed_out_kg >= 0),
    material_return_kg         INTEGER       NOT NULL DEFAULT 0 CHECK (material_return_kg >= 0),
    total_feed_consumption_kg  INTEGER       NOT NULL CHECK (total_feed_consumption_kg >= 0),
    std_p_cost                 NUMERIC(6,2),
    avg_selling_price          NUMERIC(8,3),
    gc_per_kg                  NUMERIC(5,2),
    gc_per_bird                NUMERIC(6,2),
    net_payable                NUMERIC(12,2) NOT NULL,
    production_cost_total      NUMERIC(14,2)
);

-- Four rows per batch: the cost items.
CREATE TABLE IF NOT EXISTS fact_cost_line (
    batch_no      INTEGER       NOT NULL REFERENCES dim_batch (batch_no) ON DELETE CASCADE,
    cost_item_id  SMALLINT      NOT NULL REFERENCES dim_cost_item (cost_item_id),
    amount        NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    per_kg        NUMERIC(8,2),
    PRIMARY KEY (batch_no, cost_item_id)       -- one row per batch per item: no duplicates
);

-- Thirteen rows per batch: the payout lines. Amounts are always positive;
-- the sign comes from dim_payout_item.
CREATE TABLE IF NOT EXISTS fact_payout_line (
    batch_no        INTEGER       NOT NULL REFERENCES dim_batch (batch_no) ON DELETE CASCADE,
    payout_item_id  SMALLINT      NOT NULL REFERENCES dim_payout_item (payout_item_id),
    amount          NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    qty_birds       INTEGER       CHECK (qty_birds >= 0),
    qty_kg          NUMERIC(8,2)  CHECK (qty_kg >= 0),
    description     TEXT,
    PRIMARY KEY (batch_no, payout_item_id)
);

-- Notes about special events (for example disease), reported by the farmer.
CREATE TABLE IF NOT EXISTS batch_event (
    event_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_no     INTEGER NOT NULL REFERENCES dim_batch (batch_no) ON DELETE CASCADE,
    event_type   TEXT    NOT NULL,
    description  TEXT
);


-- ---------------------------------------------------------------------
-- 3. FARM ASSUMPTIONS (the figures from the farmer: fans, hours, costs)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS farm_assumption (
    assumption_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category       TEXT NOT NULL,
    item           TEXT NOT NULL,
    value_num      NUMERIC,                 -- use for numbers
    value_text     TEXT,                    -- use for text (for example 'Mar-Jun')
    unit           TEXT,
    applies_to     TEXT NOT NULL DEFAULT 'all',
    confidence     TEXT CHECK (confidence IN ('high', 'medium', 'low')),
    UNIQUE (category, item, applies_to),
    CHECK (value_num IS NOT NULL OR value_text IS NOT NULL)
);


-- ---------------------------------------------------------------------
-- 4. REVIEW QUEUE (used later by the n8n automation)
-- Statements that fail a check land here instead of the main tables.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_queue (
    review_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_file     TEXT,
    extracted_json  JSONB       NOT NULL,   -- what the AI read
    failed_checks   TEXT[]      NOT NULL,   -- which checks failed
    status          TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'fixed', 'rejected')),
    notes           TEXT
);


-- ---------------------------------------------------------------------
-- 5. REFERENCE DATA (safe to run twice: duplicates are skipped)
-- ---------------------------------------------------------------------
INSERT INTO dim_scheme (scheme_name, std_growing_charge) VALUES
    ('2023 ALL AREA', 6.50),
    ('2026 TS & AP',  7.50)
ON CONFLICT (scheme_name) DO NOTHING;

INSERT INTO dim_cost_item (cost_item_name, display_order) VALUES
    ('Chick Cost',      1),
    ('Feed Cost',       2),
    ('Feed Suppliment', 3),
    ('Admin Cost',      4)
ON CONFLICT (cost_item_name) DO NOTHING;

INSERT INTO dim_payout_item (payout_item_name, category, effect_sign, display_order, description) VALUES
    ('Growing Charges',               'earning',             1,  1, 'Main earning: growing charge per kg x kg sold'),
    ('Incentive',                     'earning',             1,  2, 'Performance incentive per kg'),
    ('Mgmt Incentive',                'earning',             1,  3, 'Management incentive per kg'),
    ('Feed Transfer Charges',         'reimbursement',       1,  4, 'Reimbursement for moving feed between farms'),
    ('Feed Distribution Charges',     'reimbursement',       1,  5, 'Reimbursement for distributing feed'),
    ('FCR Deduction',                 'performance_penalty', -1, 6, 'Penalty for poor feed conversion'),
    ('Mortality Deduction',           'performance_penalty', -1, 7, 'Penalty for high mortality'),
    ('Birds Shortage Deduction',      'performance_penalty', -1, 8, 'Penalty for missing birds'),
    ('TDS (1%)',                      'tax',                 -1, 9, 'Tax deducted at source'),
    ('Less Feed Distribution Charges','reversal',            -1, 10,'Takes back the feed distribution amount added above'),
    ('Lame Birds Amount',             'bird_deduction',      -1, 11,'Deduction for lame birds'),
    ('Active Birds Amount',           'bird_deduction',      -1, 12,'Deduction for active birds'),
    ('Other Deductions',              'other_deduction',     -1, 13,'Purchases and other items explained in the remarks')
ON CONFLICT (payout_item_name) DO NOTHING;


-- ---------------------------------------------------------------------
-- 6. QUICK CHECK: you should see 10 tables, then the reference rows
-- ---------------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'farmledger'
ORDER BY table_name;

SELECT payout_item_name, category, effect_sign FROM dim_payout_item ORDER BY display_order;
