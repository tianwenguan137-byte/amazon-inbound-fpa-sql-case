# Business Narrative

## Executive Summary

This synthetic inbound FP&A case simulates four weeks of weekly business review reporting for a North America inbound logistics network. The reporting package compares actual shipment units and actual cost against weekly plan, then separates total variance into volume and rate impacts.

In the latest week, `2026-05-25`, the network moved `4565` units versus plan of `4520`, or `+45` units above plan. Actual cost was `10815` versus plan of `10564`, resulting in `+251` unfavorable cost variance. Actual cost improved by `-445` versus the prior week, but the week still closed above plan.

## Key Drivers

The largest variance driver across the period was a data integrity issue on `2026-05-04`: shipment `S0008` was missing actual cost data. This made the `ORD5->MSP9` lane appear artificially favorable versus plan. Before publishing WBR commentary, the missing cost record should be resolved with the source system or finance operations team.

After excluding the data quality signal, the most important business driver was `ONT8->SEA6` in week `2026-05-18`. The lane was `+605` unfavorable to plan, driven by both higher volume and higher rate:

- Volume variance: `+250`
- Rate variance: `+355`
- Total variance: `+605`

This suggests that the lane experienced both demand pressure and higher cost per unit. The rate pressure may come from carrier mix, fuel/accessorial charges, capacity constraints, or service-level changes.

## Prior Week Movement

Total actual cost increased from `9015` in week `2026-05-04` to `10255` in week `2026-05-11`, then to `11260` in week `2026-05-18`. Cost declined to `10815` in week `2026-05-25`.

The week `2026-05-25` improvement is directionally positive, but it does not fully close the gap to plan. The remaining unfavorable variance is concentrated in `ONT8->SEA6`, where actual cost was `3505` versus plan of `3250`.

## Recommended Follow-Up

For WBR discussion, the first action is to resolve missing actual cost for shipment `S0008`, then refresh the week `2026-05-04` variance view.

For business partnering, finance should review the recurring `ONT8->SEA6` rate pressure with transportation operations. Useful follow-up questions include:

- Did carrier mix shift toward a higher-cost provider?
- Were there accessorial charges tied to delays, detention, or special handling?
- Was volume above plan enough to trigger capacity constraints?
- Should the next forecast cycle adjust planned cost per unit for this lane?

## FP&A Framing

This case demonstrates an FP&A workflow that starts with data integrity, then moves to weekly performance reporting, variance analysis, and business narrative. The goal is not only to calculate the variance, but to explain what management should do next.
