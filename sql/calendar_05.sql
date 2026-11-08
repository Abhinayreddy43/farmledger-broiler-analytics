-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/calendar_05.sql
-- Step 6: a calendar table (one row per day) with the season of each day,
--         and a view with one row per batch per day.
--
-- Why: weather data arrives day by day, and season changes inside a batch
-- (batch 42 starts in winter and ends in summer). A calendar lets us join
-- weather, season and batch by DATE.
--
-- Safe to run twice. Run 'create_tables_01' and 'load_data_02' first.
-- =====================================================================

SET search_path TO farmledger;


-- ---------------------------------------------------------------------
-- 1. season_month: which season each month belongs to
-- These are your father's definitions: summer Mar-Jun, monsoon Jul-Oct,
-- winter Nov-Feb. To change a season, change it here, in one place.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS season_month (
    month_no  SMALLINT PRIMARY KEY CHECK (month_no BETWEEN 1 AND 12),
    season    TEXT     NOT NULL CHECK (season IN ('summer', 'monsoon', 'winter'))
);

INSERT INTO season_month (month_no, season) VALUES
    (1,  'winter'),  (2,  'winter'),
    (3,  'summer'),  (4,  'summer'),  (5,  'summer'),  (6,  'summer'),
    (7,  'monsoon'), (8,  'monsoon'), (9,  'monsoon'), (10, 'monsoon'),
    (11, 'winter'),  (12, 'winter')
ON CONFLICT (month_no) DO NOTHING;


-- ---------------------------------------------------------------------
-- 2. dim_date: one row per calendar day
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_date (
    date_key      DATE     PRIMARY KEY,
    year          SMALLINT NOT NULL,
    quarter       SMALLINT NOT NULL,
    month_no      SMALLINT NOT NULL REFERENCES season_month (month_no),
    month_name    TEXT     NOT NULL,
    year_month    TEXT     NOT NULL,          -- for example 2026-07, handy for charts
    day_of_month  SMALLINT NOT NULL,
    day_name      TEXT     NOT NULL,
    is_weekend    BOOLEAN  NOT NULL,
    season        TEXT     NOT NULL
);

-- generate_series makes one date per day. We cover 2024 to 2027, so new
-- batches in the next years are already inside the calendar.
INSERT INTO dim_date (date_key, year, quarter, month_no, month_name, year_month,
                      day_of_month, day_name, is_weekend, season)
SELECT g.d::date,
       EXTRACT(YEAR    FROM g.d)::smallint,
       EXTRACT(QUARTER FROM g.d)::smallint,
       EXTRACT(MONTH   FROM g.d)::smallint,
       TRIM(TO_CHAR(g.d, 'Month')),
       TO_CHAR(g.d, 'YYYY-MM'),
       EXTRACT(DAY     FROM g.d)::smallint,
       TRIM(TO_CHAR(g.d, 'Day')),
       EXTRACT(ISODOW  FROM g.d) IN (6, 7),
       sm.season
FROM generate_series('2024-01-01'::timestamp, '2027-12-31'::timestamp, interval '1 day') AS g(d)
JOIN season_month sm ON sm.month_no = EXTRACT(MONTH FROM g.d)::smallint
ON CONFLICT (date_key) DO NOTHING;


-- ---------------------------------------------------------------------
-- 3. v_batch_days: one row per batch per day of its cycle
-- day_of_cycle is 1 on the housing date. The weather will join here.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_days AS
SELECT b.batch_no,
       d.date_key,
       (d.date_key - b.housed_date + 1) AS day_of_cycle,
       d.season,
       d.year_month
FROM dim_batch b
JOIN dim_date d
  ON d.date_key BETWEEN b.housed_date AND b.liquid_date;


-- ---------------------------------------------------------------------
-- 4. CHECKS
-- ---------------------------------------------------------------------
-- A. Calendar size. Expected: 1461 days, from 2024-01-01 to 2027-12-31
SELECT COUNT(*) AS days, MIN(date_key) AS first_day, MAX(date_key) AS last_day
FROM dim_date;

-- B. Days per batch and season.
SELECT batch_no,
       COUNT(*)                                       AS total_days,
       COUNT(*) FILTER (WHERE season = 'summer')      AS summer_days,
       COUNT(*) FILTER (WHERE season = 'monsoon')     AS monsoon_days,
       COUNT(*) FILTER (WHERE season = 'winter')      AS winter_days
FROM v_batch_days
GROUP BY batch_no
ORDER BY batch_no;
