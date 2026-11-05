-- =====================================================================
-- FarmLedger: Contract Broiler Profitability and Statement Automation
-- File: sql/load_data_02.sql
-- Step 3: load the 7 batches, cost lines, payout lines and farm assumptions.
--
-- Generated from Batch_Information_master.xlsx and farm_assumptions.xlsx.
-- Safe to run twice: existing rows are updated, not duplicated.
-- Everything runs as ONE transaction: if any line fails, nothing is saved.
-- Run 'create_tables' first.
-- =====================================================================

SET search_path TO farmledger;
BEGIN;

-- 1. dim_batch (scheme_id is looked up from the scheme name)
INSERT INTO dim_batch (batch_no, farm_code, scheme_id, book_num, grade, previous_grade, area, division, housed_date, liquid_date, statement_date)
SELECT v.batch_no, v.farm_code, s.scheme_id, v.book_num, v.grade, v.previous_grade, v.area, v.division,
       v.housed_date::date, v.liquid_date::date, v.statement_date::date
FROM (VALUES
    (38, 'TS02613', '2023 ALL AREA', 5, 'D', NULL, 'Bijinapally', 'Jadcherla', '2024-12-07', '2025-01-18', '2025-01-22'),
    (39, 'TS02613', '2023 ALL AREA', 20, 'B', 'D', 'Bijinapally', 'Jadcherla', '2025-04-26', '2025-06-11', '2025-06-13'),
    (40, 'TS02613', '2023 ALL AREA', 6, 'D', 'B', 'Bijinapally', 'Bijinapally', '2025-07-29', '2025-09-05', '2025-09-11'),
    (41, 'TS02613', '2023 ALL AREA', 2, 'A', 'D', 'Bijinapally', 'Bijinapally', '2025-10-22', '2025-12-09', '2025-12-12'),
    (42, 'TS02613', '2023 ALL AREA', 18, 'C', 'A', 'Bijinapally', 'Wanaparthy', '2026-01-16', '2026-03-01', '2026-03-05'),
    (43, 'TS02613', '2023 ALL AREA', 10, 'D', 'C', 'Bijinapally', 'Wanaparthy', '2026-04-11', '2026-05-31', '2026-06-03'),
    (44, 'TS02613', '2026 TS & AP', 7, 'D', 'D', 'Bijinapally', 'Wanaparthy', '2026-07-21', '2026-08-23', '2026-09-03')
) AS v(batch_no, farm_code, scheme_name, book_num, grade, previous_grade, area, division, housed_date, liquid_date, statement_date)
JOIN dim_scheme s ON s.scheme_name = v.scheme_name
ON CONFLICT (batch_no) DO UPDATE SET
    farm_code = EXCLUDED.farm_code,
    scheme_id = EXCLUDED.scheme_id,
    book_num = EXCLUDED.book_num,
    grade = EXCLUDED.grade,
    previous_grade = EXCLUDED.previous_grade,
    area = EXCLUDED.area,
    division = EXCLUDED.division,
    housed_date = EXCLUDED.housed_date,
    liquid_date = EXCLUDED.liquid_date,
    statement_date = EXCLUDED.statement_date;

-- 2. fact_batch
INSERT INTO fact_batch (batch_no, housed_chicks, mortality, sold_birds, birds_weight_kg, excess_birds,
shortage_birds, mort_up_to_30_pct, mort_after_30_pct, first_week_mort_pct, total_mort_pct, fcr, cfcr, avg_weight_kg, mean_age_days,
day_gain_gms, eef, feed_issued_kg, feed_in_kg, feed_out_kg, material_return_kg, total_feed_consumption_kg, std_p_cost, avg_selling_price, gc_per_kg, gc_per_bird, net_payable, production_cost_total)
VALUES
    (38, 11600, 1118, 10482, 19918, 0, 0, 5.52, 4.12, 1.34, 9.64, 1.63, 1.66, 1.9, 34.64, 54.85, 304.1, 25200, 7700, 375, 0, 32525, 95, 85.539, 4.5, 8.55, 81927, 1995595.5),
    (39, 11600, 854, 10747, 25917.2, 1, 0, 3.31, 4.05, 1.45, 7.36, 1.67, 1.57, 2.412, 42.31, 57.01, 316.18, 43400, 0, 100, 0, 43300, 95, 89.515, 6.19, 14.93, 176795, 2482010),
    (40, 11810, 4014, 7796, 14481.2, 0, 0, 8.06, 25.93, 1.24, 33.99, 2.13, 2.16, 1.858, 35.55, 52.26, 161.93, 25900, 5970, 980, 0, 30890, 95, 71.28, 4.5, 8.36, 40941, 1926182),
    (41, 11587, 895, 10702, 29671.2, 10, 0, 4.38, 3.34, 1.27, 7.72, 1.69, 1.5, 2.772, 44.6, 62.15, 339.42, 47250, 6610, 3730, 0, 50130, 95, 114.656, 6.93, 19.21, 156941, 2790225.75),
    (42, 11571, 1151, 10421, 25823.7, 1, 0, 6.51, 3.44, 1.94, 9.95, 1.69, 1.58, 2.478, 40.49, 61.2, 326.12, 45500, 750, 2650, 0, 43600, 95, 109.07, 5.81, 14.4, 136627, 2497917.5),
    (43, 11541, 1127, 10416, 22337, 2, 0, 3.3, 6.46, 1.05, 9.77, 1.79, 1.76, 2.144, 43.21, 49.62, 250.18, 40250, 1750, 2100, 0, 39900, 95, 89.543, 4.5, 9.65, 118178, 2315369.5),
    (44, 11970, 6362, 5608, 9238.9, 0, 0, 8.86, 44.29, 1.59, 53.15, 3.09, 3.17, 1.647, 33.21, 49.59, 75.21, 34000, 3000, 8450, 0, 28550, 95, 63.177, 4.5, 7.41, 42290, 1828656)
ON CONFLICT (batch_no) DO UPDATE SET
    housed_chicks = EXCLUDED.housed_chicks,
    mortality = EXCLUDED.mortality,
    sold_birds = EXCLUDED.sold_birds,
    birds_weight_kg = EXCLUDED.birds_weight_kg,
    excess_birds = EXCLUDED.excess_birds,
    shortage_birds = EXCLUDED.shortage_birds,
    mort_up_to_30_pct = EXCLUDED.mort_up_to_30_pct,
    mort_after_30_pct = EXCLUDED.mort_after_30_pct,
    first_week_mort_pct = EXCLUDED.first_week_mort_pct,
    total_mort_pct = EXCLUDED.total_mort_pct,
    fcr = EXCLUDED.fcr,
    cfcr = EXCLUDED.cfcr,
    avg_weight_kg = EXCLUDED.avg_weight_kg,
    mean_age_days = EXCLUDED.mean_age_days,
    day_gain_gms = EXCLUDED.day_gain_gms,
    eef = EXCLUDED.eef,
    feed_issued_kg = EXCLUDED.feed_issued_kg,
    feed_in_kg = EXCLUDED.feed_in_kg,
    feed_out_kg = EXCLUDED.feed_out_kg,
    material_return_kg = EXCLUDED.material_return_kg,
    total_feed_consumption_kg = EXCLUDED.total_feed_consumption_kg,
    std_p_cost = EXCLUDED.std_p_cost,
    avg_selling_price = EXCLUDED.avg_selling_price,
    gc_per_kg = EXCLUDED.gc_per_kg,
    gc_per_bird = EXCLUDED.gc_per_bird,
    net_payable = EXCLUDED.net_payable,
    production_cost_total = EXCLUDED.production_cost_total;

-- 3. fact_cost_line (cost_item_id is looked up from the name)
INSERT INTO fact_cost_line (batch_no, cost_item_id, amount, per_kg)
SELECT v.batch_no, c.cost_item_id, v.amount, v.per_kg
FROM (VALUES
    (38, 'Chick Cost', 394400, 19.8),
    (38, 'Feed Cost', 1473382.5, 73.97),
    (38, 'Feed Suppliment', 58213, 2.92),
    (38, 'Admin Cost', 69600, 3.49),
    (39, 'Chick Cost', 394400, 15.22),
    (39, 'Feed Cost', 1961490, 75.68),
    (39, 'Feed Suppliment', 56520, 2.18),
    (39, 'Admin Cost', 69600, 2.69),
    (40, 'Chick Cost', 401540, 27.73),
    (40, 'Feed Cost', 1399317, 96.63),
    (40, 'Feed Suppliment', 54465, 3.76),
    (40, 'Admin Cost', 70860, 4.89),
    (41, 'Chick Cost', 393958, 13.28),
    (41, 'Feed Cost', 2270889, 76.54),
    (41, 'Feed Suppliment', 55856.75, 1.88),
    (41, 'Admin Cost', 69522, 2.34),
    (42, 'Chick Cost', 393414, 15.23),
    (42, 'Feed Cost', 1975080, 76.48),
    (42, 'Feed Suppliment', 59997.5, 2.32),
    (42, 'Admin Cost', 69426, 2.69),
    (43, 'Chick Cost', 392394, 17.57),
    (43, 'Feed Cost', 1807470, 80.92),
    (43, 'Feed Suppliment', 46259.5, 2.07),
    (43, 'Admin Cost', 69246, 3.1),
    (44, 'Chick Cost', 406980, 44.05),
    (44, 'Feed Cost', 1293315, 139.99),
    (44, 'Feed Suppliment', 56541, 6.12),
    (44, 'Admin Cost', 71820, 7.77)
) AS v(batch_no, cost_item_name, amount, per_kg)
JOIN dim_cost_item c ON c.cost_item_name = v.cost_item_name
ON CONFLICT (batch_no, cost_item_id) DO UPDATE SET
    amount = EXCLUDED.amount,
    per_kg = EXCLUDED.per_kg;

-- 4. fact_payout_line (amounts are positive; the sign comes from dim_payout_item)
INSERT INTO fact_payout_line (batch_no, payout_item_id, amount, qty_birds, qty_kg, description)
SELECT v.batch_no, i.payout_item_id, v.amount, v.qty_birds, v.qty_kg, v.description
FROM (VALUES
    (38, 'Growing Charges', 89631, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (38, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (38, 'Mgmt Incentive', 0, NULL, NULL, 'Management incentive'),
    (38, 'Feed Transfer Charges', 110, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (38, 'Feed Distribution Charges', 2160, NULL, NULL, 'Reimbursement for distributing feed'),
    (38, 'FCR Deduction', 6000, NULL, NULL, 'Penalty for poor feed conversion'),
    (38, 'Mortality Deduction', 170, NULL, NULL, 'Penalty for high mortality'),
    (38, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (38, 'TDS (1%)', 857, NULL, NULL, 'Tax deducted at source'),
    (38, 'Less Feed Distribution Charges', 2160, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (38, 'Lame Birds Amount', 787, 10, 12, 'Deduction for lame birds'),
    (38, 'Active Birds Amount', 0, 0, 0, 'Deduction for active (live) birds kept or rejected'),
    (38, 'Other Deductions', 0, NULL, NULL, 'Extra deductions explained in Remarks'),
    (39, 'Growing Charges', 160427, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (39, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (39, 'Mgmt Incentive', 25917.2, NULL, NULL, 'Management incentive'),
    (39, 'Feed Transfer Charges', 30, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (39, 'Feed Distribution Charges', 3720, NULL, NULL, 'Reimbursement for distributing feed'),
    (39, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (39, 'Mortality Deduction', 1768, NULL, NULL, 'Penalty for high mortality'),
    (39, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (39, 'TDS (1%)', 1883, NULL, NULL, 'Tax deducted at source'),
    (39, 'Less Feed Distribution Charges', 3720, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (39, 'Lame Birds Amount', 5928, 63, 85.2, 'Deduction for lame birds'),
    (39, 'Active Birds Amount', 0, 0, 0, 'Deduction for active (live) birds kept or rejected'),
    (39, 'Other Deductions', 0, NULL, NULL, 'Extra deductions explained in Remarks'),
    (40, 'Growing Charges', 65165, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (40, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (40, 'Mgmt Incentive', 0, NULL, NULL, 'Management incentive'),
    (40, 'Feed Transfer Charges', 0, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (40, 'Feed Distribution Charges', 2772.5, NULL, NULL, 'Reimbursement for distributing feed'),
    (40, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (40, 'Mortality Deduction', 949, NULL, NULL, 'Penalty for high mortality'),
    (40, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (40, 'TDS (1%)', 670, NULL, NULL, 'Tax deducted at source'),
    (40, 'Less Feed Distribution Charges', 2772.5, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (40, 'Lame Birds Amount', 0, 0, 0, 'Deduction for lame birds'),
    (40, 'Active Birds Amount', 0, 0, 0, 'Deduction for active (live) birds kept or rejected'),
    (40, 'Other Deductions', 22605, NULL, NULL, 'Deductions  for purchasing materials at Dhumal Company'),
    (41, 'Growing Charges', 205621, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (41, 'Incentive', 7417.8, NULL, NULL, 'Incentive per kg'),
    (41, 'Mgmt Incentive', 0, NULL, NULL, 'Management incentive'),
    (41, 'Feed Transfer Charges', 120, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (41, 'Feed Distribution Charges', 5197.5, NULL, NULL, 'Reimbursement for distributing feed'),
    (41, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (41, 'Mortality Deduction', 0, NULL, NULL, 'Penalty for high mortality'),
    (41, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (41, 'TDS (1%)', 2184, NULL, NULL, 'Tax deducted at source'),
    (41, 'Less Feed Distribution Charges', 5197.5, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (41, 'Lame Birds Amount', 0, 0, 0, 'Deduction for lame birds'),
    (41, 'Active Birds Amount', 4873, 25, 42.5, 'Deduction for active (live) birds kept or rejected'),
    (41, 'Other Deductions', 49161, NULL, NULL, '₹20,000 Dhumal materials and ₹29,161 Dhumal fans'),
    (42, 'Growing Charges', 150036, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (42, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (42, 'Mgmt Incentive', 0, NULL, NULL, 'Management incentive'),
    (42, 'Feed Transfer Charges', 1590, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (42, 'Feed Distribution Charges', 5005, NULL, NULL, 'Reimbursement for distributing feed'),
    (42, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (42, 'Mortality Deduction', 2322, NULL, NULL, 'Penalty for high mortality'),
    (42, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (42, 'TDS (1%)', 1543, NULL, NULL, 'Tax deducted at source'),
    (42, 'Less Feed Distribution Charges', 5005, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (42, 'Lame Birds Amount', 0, 0, 0, 'Deduction for lame birds'),
    (42, 'Active Birds Amount', 1331, 8, 12.2, 'Deduction for active (live) birds kept or rejected'),
    (42, 'Other Deductions', 9803.08, NULL, NULL, 'Extra deductions for purchasing Basket Fans at Dhumal'),
    (43, 'Growing Charges', 100517, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (43, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (43, 'Mgmt Incentive', 22337, NULL, NULL, 'Management incentive'),
    (43, 'Feed Transfer Charges', 840, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (43, 'Feed Distribution Charges', 4427.5, NULL, NULL, 'Reimbursement for distributing feed'),
    (43, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (43, 'Mortality Deduction', 0, NULL, NULL, 'Penalty for high mortality'),
    (43, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (43, 'TDS (1%)', 1281, NULL, NULL, 'Tax deducted at source'),
    (43, 'Less Feed Distribution Charges', 4427.5, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (43, 'Lame Birds Amount', 0, 0, 0, 'Deduction for lame birds'),
    (43, 'Active Birds Amount', 4235, 27, 47.3, 'Deduction for active (live) birds kept or rejected'),
    (43, 'Other Deductions', 0, NULL, NULL, 'Extra deductions'),
    (44, 'Growing Charges', 41575, NULL, NULL, 'Main earning: (GC per kg) × (kg sold)'),
    (44, 'Incentive', 0, NULL, NULL, 'Incentive per kg'),
    (44, 'Mgmt Incentive', 0, NULL, NULL, 'Management incentive'),
    (44, 'Feed Transfer Charges', 1180, NULL, NULL, 'Reimbursement for moving feed between farms'),
    (44, 'Feed Distribution Charges', 3740, NULL, NULL, 'Reimbursement for distributing feed'),
    (44, 'FCR Deduction', 0, NULL, NULL, 'Penalty for poor feed conversion'),
    (44, 'Mortality Deduction', 0, NULL, NULL, 'Penalty for high mortality'),
    (44, 'Birds Shortage Deduction', 0, NULL, NULL, 'Penalty for missing birds'),
    (44, 'TDS (1%)', 465, NULL, NULL, 'Tax deducted at source'),
    (44, 'Less Feed Distribution Charges', 3740, NULL, NULL, 'Takes back the feed distribution amount (it was added above)'),
    (44, 'Lame Birds Amount', 0, 0, 0, 'Deduction for lame birds'),
    (44, 'Active Birds Amount', 0, 0, 0, 'Deduction for active (live) birds kept or rejected'),
    (44, 'Other Deductions', 0, NULL, NULL, 'Extra deductions explained in Remarks')
) AS v(batch_no, payout_item_name, amount, qty_birds, qty_kg, description)
JOIN dim_payout_item i ON i.payout_item_name = v.payout_item_name
ON CONFLICT (batch_no, payout_item_id) DO UPDATE SET
    amount = EXCLUDED.amount,
    qty_birds = EXCLUDED.qty_birds,
    qty_kg = EXCLUDED.qty_kg,
    description = EXCLUDED.description;

-- 5. farm_assumption
INSERT INTO farm_assumption (category, item, value_num, value_text, unit, applies_to, confidence)
VALUES
    ('farm', 'shed_length', 400, NULL, 'ft', 'all', 'high'),
    ('farm', 'shed_width', 30, NULL, 'ft', 'all', 'high'),
    ('farm', 'practical_max_chicks', 12000, NULL, 'chicks per batch', 'all', 'high'),
    ('season', 'summer_months', NULL, 'Mar-Jun', 'months', 'all', 'high'),
    ('season', 'monsoon_months', NULL, 'Jul-Oct', 'months', 'all', 'high'),
    ('season', 'winter_months', NULL, 'Nov-Feb', 'months', 'all', 'high'),
    ('small_fans', 'count', 24, NULL, 'fans', 'all', 'high'),
    ('small_fans', 'watts_each', 46, NULL, 'W (rated; real draw is lower, fans have slowed)', 'all', 'medium'),
    ('small_fans', 'hours_per_day', 4.5, NULL, 'hours (range 4-5)', 'monsoon', 'medium'),
    ('small_fans', 'hours_per_day', 7, NULL, 'hours (range 6-8)', 'winter', 'medium'),
    ('small_fans', 'hours_per_day', 13, NULL, 'hours (range 12-14)', 'summer', 'medium'),
    ('big_fans', 'count', 4, NULL, 'fans', 'all', 'high'),
    ('big_fans', 'hp_each', 2, NULL, 'hp', 'all', 'high'),
    ('big_fans', 'hours_per_day', 4, NULL, 'hours', 'monsoon', 'medium'),
    ('big_fans', 'hours_per_day', 4, NULL, 'hours', 'winter', 'medium'),
    ('big_fans', 'hours_per_day', 7, NULL, 'hours (range 6-8 or more)', 'summer', 'medium'),
    ('lights', 'count', 40, NULL, 'bulbs', 'all', 'high'),
    ('lights', 'watts_each', 9, NULL, 'W', 'all', 'high'),
    ('lights', 'hours_per_day', 12, NULL, 'hours (6pm-6am)', 'all', 'high'),
    ('borewell_motor', 'hp', 1.5, NULL, 'hp, single phase', 'all', 'high'),
    ('borewell_motor', 'hours_per_day', 3.75, NULL, 'hours (range 3-4.5, not continuous)', 'summer', 'medium'),
    ('borewell_motor', 'hours_per_day', 2, NULL, 'hours', 'monsoon and winter', 'low'),
    ('water_drinking', 'litres_per_day_day1_20', 3100, NULL, 'L/day (range 3000-3200)', 'summer', 'medium'),
    ('water_drinking', 'litres_per_day_day21_end', 6000, NULL, 'L/day (more than 6000)', 'summer', 'medium'),
    ('water_drinking', 'litres_per_day_day1_20', 2000, NULL, 'L/day', 'monsoon and winter', 'medium'),
    ('water_drinking', 'litres_per_day_day21_end', 4000, NULL, 'L/day', 'monsoon and winter', 'medium'),
    ('water_drinking', 'tank_capacity', 4000, NULL, 'L (4 tanks)', 'all', 'high'),
    ('cost_per_batch', 'newspaper', 800, NULL, 'INR (20 kg x 40)', 'all', 'medium'),
    ('cost_per_batch', 'charcoal', 9000, NULL, 'INR (6 bags x 50 kg x 1500)', 'all', 'medium'),
    ('cost_per_batch', 'rice_husk', 25000, NULL, 'INR (5 tons x 5000)', 'all', 'medium'),
    ('cost_per_batch', 'soil', 8000, NULL, 'INR (4 tractor loads x 2000)', 'all', 'medium'),
    ('cost_per_batch', 'labour', 30000, NULL, 'INR (2 workers, paid only during batches)', 'all', 'high'),
    ('cost_per_batch', 'electricity', 8000, NULL, 'INR (range 7000-9000)', 'monsoon and winter', 'medium'),
    ('cost_per_batch', 'electricity', 13500, NULL, 'INR (range 12000-15000)', 'summer', 'medium'),
    ('heating', 'charcoal_days', 4.5, NULL, 'days (4-5)', 'all', 'medium'),
    ('manure', 'tractor_loads_per_batch', 10, NULL, 'loads', 'all', 'medium'),
    ('manure', 'value_per_load', 2000, NULL, 'INR', 'all', 'high'),
    ('medicines', 'paid_by', 0, NULL, 'cost covered in feed suppliment(paid by company)', 'all', 'high')
ON CONFLICT (category, item, applies_to) DO UPDATE SET
    value_num = EXCLUDED.value_num,
    value_text = EXCLUDED.value_text,
    unit = EXCLUDED.unit,
    confidence = EXCLUDED.confidence;

-- 6. batch_event (the Excel sheet is the full list, so we replace the table's rows)
DELETE FROM batch_event;
INSERT INTO batch_event (batch_no, event_type, description)
VALUES
    (40, 'Disease', 'Bird flu, diseases and infections; heat may also have contributed'),
    (44, 'Disease', 'Bird flu, diseases and infections; heat may also have contributed');

COMMIT;


-- =====================================================================
-- CHECKS (run after loading)
-- =====================================================================

-- A. Row counts. Expected: 7, 7, 28, 91, 38, 2
SELECT 'dim_batch' AS table_name, COUNT(*) AS rows FROM dim_batch
UNION ALL SELECT 'fact_batch',       COUNT(*) FROM fact_batch
UNION ALL SELECT 'fact_cost_line',   COUNT(*) FROM fact_cost_line
UNION ALL SELECT 'fact_payout_line', COUNT(*) FROM fact_payout_line
UNION ALL SELECT 'farm_assumption',  COUNT(*) FROM farm_assumption
UNION ALL SELECT 'batch_event',      COUNT(*) FROM batch_event;

-- B. Do the payout lines add up to the printed net payable? (allow 1 rupee rounding)
SELECT p.batch_no,
       SUM(p.amount * i.effect_sign)                          AS calculated_net,
       f.net_payable                                           AS printed_net,
       ROUND(SUM(p.amount * i.effect_sign) - f.net_payable, 2) AS difference,
       ABS(SUM(p.amount * i.effect_sign) - f.net_payable) <= 1 AS ok
FROM fact_payout_line p
JOIN dim_payout_item i USING (payout_item_id)
JOIN fact_batch f      USING (batch_no)
GROUP BY p.batch_no, f.net_payable
ORDER BY p.batch_no;
