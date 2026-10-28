# Order-Level SLA Replay — Baseline Data Audit

## Purpose

Read-only audit of the current trusted raw exports before implementing a new order-level, capacity-constrained replay. No source CSVs, generator, dbt models, or frozen marts were modified.

## Source-derived baseline

- Orders: **5,636**
- Order-item rows: **85,221**
- Hourly demand rows: **720**
- Hourly capacity rows: **720**
- KPI telemetry rows: **720**
- Total order units: **170,212**
- Aggregate hourly units picked: **170,212**
- Existing order statuses: Dispensed=5,515, Delayed=117, Backlog=4
- Expedite split: **1,117 expedited**, **4,519 standard**
- Deadline rule: **1,117 one-hour leads** and **4,519 two-hour leads**; mismatch count vs `is_expedited` rule = **0**
- Aggregate backlog conservation errors: **0**
- Aggregate peak backlog: **953 units**; final aggregate backlog: **0 units**

## Material reconciliation finding

The hourly aggregate model reports **170,212 units picked** and zero ending backlog. The order-level status/timestamp output accounts for only **170,085 units in completed orders**; the **127 units** belonging to 4 Backlog orders remain uncompleted. Thus the existing order-level completion output does not reconcile to the aggregate throughput record: **127 units** of aggregate throughput are not assigned to completed orders.

The issue is not a missing SLA deadline. The current generator already has the arrival, units, expedited flag, deadline, completion timestamp, and status. The issue is the relationship between hourly aggregate throughput and its order-level allocation/completion timestamps.

Additional diagnostic: **3,199** completed orders have `actual_picked_at` exactly equal to `order_placed_at`. Also, when completed order units are grouped by their recorded completion hour, the result differs from aggregate `units_picked` in **463 of 720 hours**; the sum of absolute hourly differences is **7,287 units**. This makes the recorded completion timestamps unsuitable as a validated minute-level service trace without further reconstruction.

## Modeling consequence

Do **not** silently treat the generator's recorded `actual_picked_at` values as ground truth for a new replay, and do not change the frozen dbt marts to compensate. Preserve these raw exports as the baseline evidence. The replay should use a separate, explicit event/queue model:

1. Orders enter the queue at `order_placed_at`.
2. Each order carries `units_required`, `is_expedited`, and its existing `requested_pickup_at` deadline.
3. FIFO is the initial queue discipline, as agreed.
4. Effective hourly capacity comes from the validated operating context; capacity is only consumed after work has arrived.
5. Completion occurs only when the full order workload has been processed. SLA status is then derived from completion vs deadline; incomplete orders remain open at the simulation horizon.
6. Validate hourly and total unit conservation, order-level completion, queue age/composition, and SLA metrics. Compare this replay against existing aggregate results and document any differences rather than forcing artificial agreement.

## Files

- `baseline_audit_summary.json`: machine-readable summary.
- `order_level_baseline_audit.csv`: order fields plus reconciled item-unit totals and diagnostic flags.
- `hourly_aggregate_vs_order_completion_audit.csv`: hourly aggregate records joined to capacity telemetry and order-completion units.
- `audit_order_level_baseline.py`: reproducible, read-only audit script.
