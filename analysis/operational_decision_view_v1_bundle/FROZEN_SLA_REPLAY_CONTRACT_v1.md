# Frozen Order-Level SLA Replay Contract — v1

**Status:** Accepted for intervention experiments. This contract freezes the replay's interpretation; it does not claim that generator order-status labels are reproduced.

## Order semantics
- Source arrival: `order_placed_at`.
- Required work: sum of `raw_order_items.quantity`, validated against `raw_orders.units_required`.
- SLA deadline: `requested_pickup_at`, already generated as one hour after arrival for expedited orders and two hours for standard orders.
- Priority: `is_expedited`; priority changes the deadline, not queue position in this v1 contract.
- Queue discipline: FIFO by `order_placed_at`, with `order_id` as deterministic tie-breaker.
- Completion: only after all units required by the order are processed.

## Capacity semantics
- Capacity is the hourly `effective_capacity_units` reconstructed from raw labor and capacity fields; reconstruction must exactly match telemetry for all 720 hours.
- Capacity is a piecewise-constant rate within each hour. Unused capacity before an order arrives is not banked.
- Work is processed continuously; the queue advances only when work is available and capacity is positive.
- `target_kpi_value` remains fixed across intervention scenarios. Interventions change modeled resources/productivity only.

## SLA and backlog measures
- Completed late: completion time is strictly after `requested_pickup_at`.
- Open overdue: order is still incomplete at the snapshot/horizon and its deadline has passed.
- SLA attainment by horizon: one minus all orders late or open-overdue divided by total orders.
- Backlog snapshots report open orders, remaining units, overdue orders/units, priority composition, and oldest open-order age.

## Known limits
- No independent staging-ready or customer-handoff timestamp exists in the raw order records. The replay is a combined fulfillment capacity model, not separate picking/staging/handoff queues.
- Generator status labels (`Delayed`, `Backlog`, `Dispensed`) are retained for comparison but are not used to dictate replay outcomes. Generator `Delayed` count (117) differs from FIFO replay late-completion count (37).
- Labor cost is not a source fact. Cost sensitivity uses illustrative fully loaded hourly rates; do not present a single cost as validated until an owner supplies the agreed rate.
- Incident staging relief and productivity uplift are modeled upper-bound/sensitivity interventions, not verified engineering or implementation plans.
