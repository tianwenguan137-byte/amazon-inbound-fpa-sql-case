-- Amazon Inbound FP&A SQL Case
-- Run after loading the CSV files into the SQLite tables created by schema.sql.

-- 1. Weekly WBR summary with prior week comparison.
SELECT *
FROM weekly_wbr_summary
ORDER BY week_start;

-- 2. Actual vs plan variance bridge by week and lane.
SELECT *
FROM variance_bridge
ORDER BY week_start, ABS(total_variance) DESC;

-- 3. Top variance drivers across the reporting period.
SELECT *
FROM top_variance_drivers
ORDER BY variance_rank;

-- 4. Data integrity check: shipments missing actual cost data.
SELECT *
FROM missing_cost_records
ORDER BY week_start, shipment_id;

-- 5. Data integrity check: actual cost component totals.
SELECT *
FROM cost_reconciliation_issues
ORDER BY shipment_id;
