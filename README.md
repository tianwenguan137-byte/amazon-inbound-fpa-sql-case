# Amazon Inbound FP&A SQL Case

This project uses synthetic logistics and finance data to simulate an inbound FP&A reporting workflow. The data is simulated for portfolio purposes only. It is not Amazon internal data, does not represent Amazon operations, and does not contain confidential company data.

## Project Goal

Build a small SQL-based reporting case that mirrors common FP&A work for an inbound logistics network:

- Pull shipment, actual cost, and weekly plan data
- Build a weekly WBR-style summary
- Compare actuals vs plan
- Calculate cost per unit
- Identify top variance drivers
- Build a volume/rate variance bridge
- Compare current week to prior week
- Check missing cost data before interpreting results
- Summarize the business narrative for finance and operations partners

## Repo Structure

```text
.
├── data/
│   ├── shipments.csv
│   ├── actual_costs.csv
│   └── weekly_plan.csv
├── sql/
│   ├── schema.sql
│   └── queries.sql
├── outputs/
│   ├── wbr_summary.csv
│   ├── variance_bridge.csv
│   └── top_variance_drivers.csv
└── notes/
    └── business_narrative.md
```

## Data Model

`shipments.csv` contains synthetic shipment-level operational data, including week, lane, carrier, units, transit days, and on-time status.

`actual_costs.csv` contains synthetic shipment-level finance data, including linehaul cost, fuel surcharge, accessorial cost, total cost, and invoice status.

`weekly_plan.csv` contains synthetic weekly plan data by region and lane, including planned units, planned cost, and forecast cost per unit.

## SQL Workflow

The SQLite workflow in `sql/schema.sql` creates base tables and reporting views:

- `shipment_cost_detail`: joins shipments to actual cost records
- `lane_week_actuals`: summarizes actual units, cost, cost per unit, and on-time performance by week and lane
- `lane_week_plan_actual`: compares actuals to weekly plan
- `weekly_wbr_summary`: produces a weekly WBR summary with prior week comparison
- `variance_bridge`: separates volume variance and rate variance
- `top_variance_drivers`: ranks the largest unfavorable or favorable variances
- `missing_cost_records`: checks for shipments missing cost data
- `cost_reconciliation_issues`: checks whether cost components reconcile to total cost

## Variance Bridge Logic

The bridge separates total cost variance into volume and rate:

```text
Total variance = Actual cost - Planned cost
Volume variance = (Actual units - Planned units) * Planned cost per unit
Rate variance = Actual cost - (Actual units * Planned cost per unit)
```

This helps distinguish whether cost movement came from higher/lower volume or from cost per unit changes.

## How to Reproduce

Prerequisite: SQLite installed locally.

From the project root:

```bash
mkdir -p work outputs
sqlite3 work/inbound_fpa.db < sql/schema.sql

sqlite3 work/inbound_fpa.db <<'SQL'
.mode csv
.import --skip 1 data/shipments.csv shipments
.import --skip 1 data/actual_costs.csv actual_costs
.import --skip 1 data/weekly_plan.csv weekly_plan
SQL

sqlite3 -header -csv work/inbound_fpa.db \
  "SELECT * FROM weekly_wbr_summary ORDER BY week_start;" \
  > outputs/wbr_summary.csv

sqlite3 -header -csv work/inbound_fpa.db \
  "SELECT * FROM variance_bridge ORDER BY week_start, ABS(total_variance) DESC;" \
  > outputs/variance_bridge.csv

sqlite3 -header -csv work/inbound_fpa.db \
  "SELECT * FROM top_variance_drivers ORDER BY variance_rank;" \
  > outputs/top_variance_drivers.csv
```

To inspect all core queries:

```bash
sqlite3 -header -column work/inbound_fpa.db < sql/queries.sql
```

## Output Highlights

- Week `2026-05-18` had the highest unfavorable cost variance: actual cost `11260` vs plan `10405`, or `+855` unfavorable.
- The largest operating driver was lane `ONT8->SEA6` in week `2026-05-18`, with `+605` total variance split into `+250` volume variance and `+355` rate variance.
- Week `2026-05-25` improved by `-445` vs prior week, but still finished `+251` above plan.
- Shipment `S0008` is missing actual cost data, which creates a data integrity issue for the `2026-05-04` WBR.

## Business Takeaway

The analysis shows how an FP&A analyst can use SQL to move from raw shipment and cost data to a concise weekly reporting package. The most important finance insight is that not every variance should be explained immediately as business performance: missing cost records must be resolved first, and then the remaining cost movement can be separated into volume-driven and rate-driven impacts.

## GitHub Upload Steps

Suggested repository name: `amazon-inbound-fpa-sql-case`

```bash
git init
git add README.md .gitignore data sql outputs notes
git commit -m "Add inbound FP&A SQL case"
git branch -M main
git remote add origin https://github.com/<your-username>/amazon-inbound-fpa-sql-case.git
git push -u origin main
```
