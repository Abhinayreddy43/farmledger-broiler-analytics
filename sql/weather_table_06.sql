-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/weather_table_06.sql
-- Step 7: the table that will hold the daily weather at the farm.
--
-- This step only creates the (empty) table. In the next step, n8n fetches
-- the data from Open-Meteo and saves it here, one row per day.
--
-- Safe to run twice. Run 'calendar_05' first (this table points to dim_date).
-- =====================================================================

SET search_path TO farmledger;

CREATE TABLE IF NOT EXISTS fact_weather_day (
    weather_date        DATE PRIMARY KEY REFERENCES dim_date (date_key),  -- one row per day
    latitude            NUMERIC(8,5),             -- the point we asked Open-Meteo about
    longitude           NUMERIC(8,5),
    temp_max_c          NUMERIC(4,1) CHECK (temp_max_c  BETWEEN -10 AND 60),
    temp_min_c          NUMERIC(4,1) CHECK (temp_min_c  BETWEEN -10 AND 60),
    temp_mean_c         NUMERIC(4,1) CHECK (temp_mean_c BETWEEN -10 AND 60),
    humidity_mean_pct   NUMERIC(4,1) CHECK (humidity_mean_pct BETWEEN 0 AND 100),
    precipitation_mm    NUMERIC(6,1) CHECK (precipitation_mm >= 0),
    source              TEXT        NOT NULL DEFAULT 'open-meteo-archive',
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (temp_min_c <= temp_max_c)              -- the minimum can never be above the maximum
);

COMMENT ON TABLE fact_weather_day IS
    'Daily weather at the farm. One farm only, so the date is the key. A second farm would need a location key.';


-- ---------------------------------------------------------------------
-- CHECKS
-- ---------------------------------------------------------------------
-- A. The table exists and is empty for now. Expected: 0 rows
SELECT COUNT(*) AS weather_rows FROM fact_weather_day;

-- B. The dates the weather must cover. n8n will ask Open-Meteo for this
--    whole range in one request.
--    Expected: 2024-12-07 to 2026-08-23
SELECT MIN(housed_date) AS first_date,
       MAX(liquid_date) AS last_date,
       MAX(liquid_date) - MIN(housed_date) + 1 AS days_needed
FROM dim_batch;
