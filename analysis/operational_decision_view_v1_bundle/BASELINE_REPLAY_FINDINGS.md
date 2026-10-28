# Order-Level SLA Replay — Baseline v1 Findings

## Status

**Initial replay implemented; internal accounting checks pass. Not yet certified as a replacement for the generator's existing SLA output.** The output is an explicitly defined alternative replay that can be used to validate and compare model behavior before intervention scenarios are run.

## Inputs and safeguards

- Reads the trusted raw exports from `/mnt/data/work/`.
- Rebuilds each order's required units from `raw_order_items.csv` and verifies the result against `raw_orders.units_required`.
- Reconstructs effective capacity from raw labor capacity and hourly staging/system capacity, then compares it to `raw_kpi_telemetry.effective_capacity_units`.
- Does not rerun or modify the generator, raw exports, dbt models, or frozen `fct_operating_envelope` / `fct_kpi_attainability` marts.

## Replay rule

The replay uses a **continuous-work FIFO fluid queue**. Capacity is a piecewise-constant service rate in units/hour for each hour. Work can be processed only after the order arrives; capacity from earlier idle time is not banked. Orders are processed FIFO, including expedited orders, while their different deadlines remain in force. Completion occurs only after the full order workload is processed. SLA misses are derived from completion time versus `requested_pickup_at`.

This is a modeling choice, not a claim that the original generator implements minute-level service this way. It is deliberately explicit and testable.

## Internal validation results

All nine automated invariants pass:

1. Order units equal summed item quantities.
2. Reconstructed effective capacity matches telemetry in all 720 hours.
3. Total processed work reconciles to total order units within numerical tolerance.
4. Completed work plus remaining work reconciles to all order units.
5. No order completes before arrival.
6. All recorded completions occur within the replay horizon.
7. Completion order is FIFO.
8. Service never exceeds each hour's effective-capacity limit.
9. SLA miss flags are derived from the deadline comparison.

## Baseline v1 result (model-defined, not yet generator-equivalent)

- Orders: **5,636**; order-item rows: **85,221**.
- Total units: **170,212**; all **170,212** are processed by the horizon.
- Effective-capacity reconstruction mismatches: **0 / 720 hours**.
- Completed orders: **5,636**; open orders at the horizon: **0**.
- Completed late: **37**; SLA attainment by the horizon: **99.34%** under this replay's definition.
- Peak open queue: **33 orders / about 992 units**.
- Peak overdue queue: **3 orders**; oldest open order at an hourly snapshot: **2.03 hours**.
- Late-completion delay: median **9.15 minutes**, 90th percentile **60.14 minutes**, maximum **71.09 minutes**.
- Labor cost is not monetized because no validated wage assumption is present. Scenario comparison should first report incremental labor-hours; cost can be added when an hourly cost assumption is approved.

## Why the original output is not a valid minute-level benchmark yet

The current generator's raw output has **117 `Delayed` orders** and **4 `Backlog` orders**. Its aggregate hourly table reports **170,212 units picked** and zero ending backlog, while completed order records account for **170,085 units** and the four open orders contain **127 units**. In addition, **3,199** completed orders have `actual_picked_at` exactly equal to `order_placed_at`, and grouping completed order units by recorded completion hour differs from aggregate hourly throughput in **463 of 720 hours**.

These are order-allocation/completion-timestamp inconsistencies, not missing deadline fields and not evidence of a defect in the frozen dbt marts. The new replay therefore does not reuse those completion timestamps as truth. The difference between 117 source-generator delayed statuses and 37 replay SLA misses is material and must remain visible; do not present the new replay as generator-equivalent without explaining the different order-allocation logic.

## Scope boundary: picking vs separate fulfillment stages

The current source has `actual_picked_at` but no distinct order-level timestamps for staging-ready or customer handoff/dispensing. The current effective-capacity formula combines labor and staging constraints into one hourly service limit. Therefore, this first replay models **order fulfillment through a combined effective-capacity constraint**. It can identify when staging limits effective capacity at the hourly level, but it cannot honestly claim to simulate separate picking, staging-queue, and dispensing stages. Separate stage queues would require additional explicit model assumptions and likely a future generator/schema version.

## Next gate before interventions

Review the model-defined baseline and its assumptions, especially:

- continuous service within an hour versus hourly aggregate throughput;
- FIFO regardless of expedited flag, with expedited priority represented by the shorter deadline only;
- combined effective capacity rather than separate order-level picking and staging stages;
- SLA attainment denominator and treatment of orders still overdue at the horizon.

Once this baseline is accepted, freeze the replay contract and run four separate intervention experiments: labor reallocation, incremental labor, staging-capacity relief, and productivity uplift. Report service outcomes, backlog age/composition, incremental labor hours, and the remaining binding constraint together.
