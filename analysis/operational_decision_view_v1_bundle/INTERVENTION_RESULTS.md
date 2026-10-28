# Order-level SLA replay — intervention results v1

## Decision summary

All four interventions were run against the same frozen FIFO baseline. The baseline order completion timestamps match the previously audited replay exactly. All scenarios preserve the 5,636 orders and 170,212 required units; the KPI target, demand, order sizes, order arrival times, and deadlines remain fixed.

| Scenario | Late orders | SLA attainment | Change vs baseline | Peak open units | Peak overdue orders | Max open-order age | Incremental labor-hours |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline FIFO | 37 | 99.344% | — | 992.0 | 3 | 2.03 h | 0 |
| Reallocate 1 associate Night → Morning | 18 | 99.681% | -19 late orders | 782.5 | 4 | 3.17 h | 0 |
| Add 1 Morning associate | 4 | 99.929% | -33 late orders | 782.5 | 0 | 1.22 h | 240 |
| Remove incident staging restrictions | 15 | 99.734% | -22 late orders | 900.8 | 1 | 1.23 h | 0 |
| Productivity +10% | 11 | 99.805% | -26 late orders | 782.9 | 3 | 1.50 h | 0 |

## What the experiment suggests

- **Additional morning labor has the strongest modeled service result:** 4 late orders versus 37 at baseline, with 240 incremental labor-hours. Under illustrative fully loaded labor rates of $25/$35/$45 per hour, that is $6,000/$8,400/$10,800 incremental labor cost, or approximately $182/$255/$327 per baseline SLA miss avoided. This is a sensitivity calculation, not a validated business ROI; it excludes recruiting/scheduling friction, overtime premiums, benefits differences, and downstream value of on-time orders.
- **Night-to-morning reallocation improves the total late-order count without adding labor-hours** (18 late vs 37), but it increases the maximum age of an open order from 2.03 to 3.17 hours and the peak overdue queue from 3 to 4 orders. That is a real service-composition tradeoff: moving capacity improves the high-demand window but leaves some work waiting longer overnight.
- **Staging relief reduces late orders to 15** and lowers peak overdue units, but it is an idealized upper bound: the model removes incident-related capacity restrictions without assigning remediation cost or proving the physical staging intervention is feasible.
- **A 10% productivity uplift reduces late orders to 11** with no extra modeled labor-hours, but its implementation cost is not modeled. It is a sensitivity scenario, not a free intervention.
- Every scenario completes all orders by the 30-day horizon. The differentiator is timeliness and intermediate backlog exposure, not final order completion.

## Labor cost assumptions

The source data contains no validated fully loaded hourly labor cost. The $25, $35, and $45 per labor-hour values are deliberately illustrative sensitivity points. Keep incremental labor-hours as the primary reported measure until an agreed business rate is supplied. Reallocation is modeled as zero net labor-hours; it is not costless in every real operating environment because shift differentials, overtime, handoffs, and availability may differ.

## Contract and limitations

- FIFO by order arrival, tie-break by `order_id`; expedited orders retain their one-hour deadline and standard orders their two-hour deadline as provided by `requested_pickup_at`.
- Continuous-work queue with piecewise-constant hourly capacity; no capacity is banked before arrival; an order completes only after all required units are processed.
- Frozen KPI target is unchanged. No demand, order sizes, order arrival times, or deadlines change across scenarios.
- There are no separate staging-ready or customer-handoff timestamps, so stage-level waiting and customer handoff SLA cannot be independently estimated.
- The generator labels 117 orders `Delayed`, while the explicit FIFO replay calculates 37 late completions. This pre-existing source-model discrepancy remains visible; do not interpret the replay as reproducing the generator’s status labels. The baseline replay’s completion times are identical to the previous audited replay.
- The capacity-reduction removal scenario is an upper-bound idealization. Productivity uplift has no associated implementation cost. Labor reallocation moves one actual associate per day from the eight-hour Night shift to the eight-hour Morning shift; additional labor adds one associate to each Morning shift (240 hours across 30 days).
