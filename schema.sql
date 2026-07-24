DROP VIEW IF EXISTS top_variance_drivers;
DROP VIEW IF EXISTS variance_bridge;
DROP VIEW IF EXISTS weekly_wbr_summary;
DROP VIEW IF EXISTS lane_week_plan_actual;
DROP VIEW IF EXISTS lane_week_actuals;
DROP VIEW IF EXISTS shipment_cost_detail;
DROP VIEW IF EXISTS missing_cost_records;
DROP VIEW IF EXISTS cost_reconciliation_issues;

DROP TABLE IF EXISTS actual_costs;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS weekly_plan;

CREATE TABLE shipments (
    shipment_id TEXT PRIMARY KEY,
    week_start TEXT NOT NULL,
    region TEXT NOT NULL,
    lane TEXT NOT NULL,
    origin_fc TEXT NOT NULL,
    destination_fc TEXT NOT NULL,
    carrier TEXT NOT NULL,
    ship_mode TEXT NOT NULL,
    units INTEGER NOT NULL,
    planned_transit_days INTEGER NOT NULL,
    actual_transit_days INTEGER NOT NULL,
    on_time_flag INTEGER NOT NULL CHECK (on_time_flag IN (0, 1))
);

CREATE TABLE actual_costs (
    shipment_id TEXT PRIMARY KEY,
    linehaul_cost REAL NOT NULL,
    fuel_surcharge REAL NOT NULL,
    accessorial_cost REAL NOT NULL,
    total_cost REAL NOT NULL,
    invoice_status TEXT NOT NULL
);

CREATE TABLE weekly_plan (
    week_start TEXT NOT NULL,
    region TEXT NOT NULL,
    lane TEXT NOT NULL,
    planned_units INTEGER NOT NULL,
    planned_cost REAL NOT NULL,
    forecast_cost_per_unit REAL NOT NULL,
    PRIMARY KEY (week_start, region, lane)
);

CREATE VIEW shipment_cost_detail AS
SELECT
    s.shipment_id,
    s.week_start,
    s.region,
    s.lane,
    s.origin_fc,
    s.destination_fc,
    s.carrier,
    s.ship_mode,
    s.units,
    s.planned_transit_days,
    s.actual_transit_days,
    s.on_time_flag,
    c.linehaul_cost,
    c.fuel_surcharge,
    c.accessorial_cost,
    c.total_cost,
    c.invoice_status,
    CASE WHEN c.shipment_id IS NULL THEN 1 ELSE 0 END AS missing_cost_flag,
    CASE WHEN c.shipment_id IS NULL THEN 0 ELSE s.units END AS costed_units,
    CASE
        WHEN c.total_cost IS NULL THEN NULL
        ELSE ROUND(c.total_cost * 1.0 / NULLIF(s.units, 0), 4)
    END AS shipment_cost_per_unit
FROM shipments s
LEFT JOIN actual_costs c
    ON s.shipment_id = c.shipment_id;

CREATE VIEW lane_week_actuals AS
SELECT
    week_start,
    region,
    lane,
    COUNT(*) AS shipment_count,
    SUM(units) AS actual_units,
    SUM(costed_units) AS costed_units,
    ROUND(COALESCE(SUM(total_cost), 0), 2) AS actual_cost,
    SUM(on_time_flag) AS on_time_shipments,
    ROUND(SUM(on_time_flag) * 100.0 / NULLIF(COUNT(*), 0), 1) AS on_time_rate_pct,
    ROUND(AVG(actual_transit_days), 2) AS avg_actual_transit_days,
    SUM(missing_cost_flag) AS missing_cost_shipments,
    ROUND(COALESCE(SUM(total_cost), 0) * 1.0 / NULLIF(SUM(units), 0), 4) AS reported_cost_per_unit,
    ROUND(COALESCE(SUM(total_cost), 0) * 1.0 / NULLIF(SUM(costed_units), 0), 4) AS costed_cost_per_unit
FROM shipment_cost_detail
GROUP BY week_start, region, lane;

CREATE VIEW lane_week_plan_actual AS
WITH joined AS (
    SELECT
        p.week_start,
        p.region,
        p.lane,
        p.planned_units,
        p.planned_cost,
        p.forecast_cost_per_unit,
        COALESCE(a.shipment_count, 0) AS shipment_count,
        COALESCE(a.actual_units, 0) AS actual_units,
        COALESCE(a.costed_units, 0) AS costed_units,
        COALESCE(a.actual_cost, 0) AS actual_cost,
        COALESCE(a.on_time_shipments, 0) AS on_time_shipments,
        a.on_time_rate_pct,
        a.avg_actual_transit_days,
        COALESCE(a.missing_cost_shipments, 0) AS missing_cost_shipments,
        a.reported_cost_per_unit,
        a.costed_cost_per_unit
    FROM weekly_plan p
    LEFT JOIN lane_week_actuals a
        ON p.week_start = a.week_start
       AND p.region = a.region
       AND p.lane = a.lane
),
metrics AS (
    SELECT
        *,
        planned_cost * 1.0 / NULLIF(planned_units, 0) AS plan_cost_per_unit,
        actual_cost * 1.0 / NULLIF(actual_units, 0) AS actual_cost_per_unit
    FROM joined
)
SELECT
    week_start,
    region,
    lane,
    planned_units,
    actual_units,
    actual_units - planned_units AS unit_variance,
    ROUND(planned_cost, 2) AS planned_cost,
    ROUND(actual_cost, 2) AS actual_cost,
    ROUND(actual_cost - planned_cost, 2) AS cost_variance,
    ROUND((actual_cost - planned_cost) * 100.0 / NULLIF(planned_cost, 0), 1) AS cost_variance_pct,
    ROUND(plan_cost_per_unit, 4) AS plan_cost_per_unit,
    ROUND(actual_cost_per_unit, 4) AS actual_cost_per_unit,
    ROUND((actual_units - planned_units) * plan_cost_per_unit, 2) AS volume_variance,
    ROUND(actual_cost - (actual_units * plan_cost_per_unit), 2) AS rate_variance,
    shipment_count,
    on_time_shipments,
    on_time_rate_pct,
    avg_actual_transit_days,
    missing_cost_shipments
FROM metrics;

CREATE VIEW weekly_wbr_summary AS
WITH weekly AS (
    SELECT
        week_start,
        SUM(actual_units) AS actual_units,
        SUM(planned_units) AS planned_units,
        SUM(actual_cost) AS actual_cost,
        SUM(planned_cost) AS planned_cost,
        SUM(shipment_count) AS shipment_count,
        SUM(on_time_shipments) AS on_time_shipments,
        SUM(missing_cost_shipments) AS missing_cost_shipments
    FROM lane_week_plan_actual
    GROUP BY week_start
),
metrics AS (
    SELECT
        week_start,
        actual_units,
        planned_units,
        actual_units - planned_units AS unit_variance,
        ROUND(actual_cost, 2) AS actual_cost,
        ROUND(planned_cost, 2) AS planned_cost,
        ROUND(actual_cost - planned_cost, 2) AS cost_variance,
        ROUND((actual_cost - planned_cost) * 100.0 / NULLIF(planned_cost, 0), 1) AS cost_variance_pct,
        ROUND(actual_cost * 1.0 / NULLIF(actual_units, 0), 4) AS actual_cost_per_unit,
        ROUND(planned_cost * 1.0 / NULLIF(planned_units, 0), 4) AS plan_cost_per_unit,
        shipment_count,
        ROUND(on_time_shipments * 100.0 / NULLIF(shipment_count, 0), 1) AS on_time_rate_pct,
        missing_cost_shipments
    FROM weekly
)
SELECT
    week_start,
    actual_units,
    planned_units,
    unit_variance,
    actual_cost,
    planned_cost,
    cost_variance,
    cost_variance_pct,
    actual_cost_per_unit,
    plan_cost_per_unit,
    shipment_count,
    on_time_rate_pct,
    missing_cost_shipments,
    LAG(actual_cost) OVER (ORDER BY week_start) AS prior_week_actual_cost,
    ROUND(actual_cost - LAG(actual_cost) OVER (ORDER BY week_start), 2) AS prior_week_cost_change
FROM metrics;

CREATE VIEW variance_bridge AS
SELECT
    week_start,
    region,
    lane,
    planned_units,
    actual_units,
    unit_variance,
    planned_cost,
    actual_cost,
    cost_variance AS total_variance,
    plan_cost_per_unit,
    actual_cost_per_unit,
    volume_variance,
    rate_variance,
    missing_cost_shipments
FROM lane_week_plan_actual;

CREATE VIEW top_variance_drivers AS
SELECT
    variance_rank,
    week_start,
    region,
    lane,
    planned_units,
    actual_units,
    planned_cost,
    actual_cost,
    total_variance,
    volume_variance,
    rate_variance,
    missing_cost_shipments,
    driver_note
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ABS(total_variance) DESC, week_start, lane) AS variance_rank,
        week_start,
        region,
        lane,
        planned_units,
        actual_units,
        planned_cost,
        actual_cost,
        total_variance,
        volume_variance,
        rate_variance,
        missing_cost_shipments,
        CASE
            WHEN missing_cost_shipments > 0 THEN 'Data quality: missing cost record'
            WHEN ABS(rate_variance) >= ABS(volume_variance) AND rate_variance > 0 THEN 'Rate pressure'
            WHEN ABS(rate_variance) >= ABS(volume_variance) AND rate_variance < 0 THEN 'Rate favorability'
            WHEN volume_variance > 0 THEN 'Volume above plan'
            ELSE 'Volume below plan'
        END AS driver_note
    FROM variance_bridge
)
WHERE variance_rank <= 10;

CREATE VIEW missing_cost_records AS
SELECT
    shipment_id,
    week_start,
    region,
    lane,
    carrier,
    ship_mode,
    units
FROM shipment_cost_detail
WHERE missing_cost_flag = 1;

CREATE VIEW cost_reconciliation_issues AS
SELECT
    shipment_id,
    linehaul_cost,
    fuel_surcharge,
    accessorial_cost,
    total_cost,
    ROUND(total_cost - (linehaul_cost + fuel_surcharge + accessorial_cost), 2) AS difference
FROM actual_costs
WHERE ABS(total_cost - (linehaul_cost + fuel_surcharge + accessorial_cost)) > 0.01;
