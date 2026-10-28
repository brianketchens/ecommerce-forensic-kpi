# Operational SLA Decision View — Prototype v1

## What this is
A self-contained interactive HTML decision view based on the frozen order-level FIFO SLA replay contract v1 and the five scenario outputs (baseline plus four interventions). Open `operational_decision_view_v1_index_refined.html` in a modern browser; no server or external JavaScript library is required.

## What can be explored
- Compare missed orders across the baseline and four interventions.
- Select a scenario to inspect SLA attainment, late orders, peak queue, overdue queue, lateness, and labor-hours.
- Change an illustrative fully loaded labor rate ($15–$70/hour) to see incremental labor-cost sensitivity and simple cost per SLA miss avoided.
- Compare expedited vs standard SLA results under the contract's FIFO rule.

## Decision caveats
- This is an interactive prototype using bundled outputs, not a live-connected dashboard or deployed CI/CD artifact yet.
- Cost rates are illustrative only. Only the additional morning associate scenario adds modeled labor-hours (240). Reallocation, staging relief, and productivity improvement omit real implementation costs.
- Staging relief is an idealized upper-bound scenario; productivity uplift is a sensitivity, not a measured improvement.
- No separate staging-ready or customer-handoff timestamps exist.
- Generator status labels report 117 `Delayed` orders, while the frozen replay computes 37 baseline SLA misses. This remains a Phase 2 model-fidelity issue.
- All scenarios preserve the same orders, order sizes, arrival times, deadlines, and KPI target.

## Files
- `operational_decision_view_v1_index_refined.html`: self-contained interactive view.
- `intervention_scenario_comparison.csv`: primary scenario metrics.
- `intervention_sla_by_priority.csv`: priority breakdown.
- `intervention_peak_backlog_composition.csv`: peak backlog composition.
- `intervention_validation_checks.json`: automated integrity checks.
- `FROZEN_SLA_REPLAY_CONTRACT_v1.md`: agreed replay rules.
- `INTERVENTION_RESULTS.md`: experiment findings and limitations.
- `BASELINE_DATA_AUDIT.md`, `BASELINE_REPLAY_FINDINGS.md`: baseline audit trail.
- `source_manifest.csv`: source provenance.

## Next engineering milestone
Once the decision logic and labels are reviewed, separate the replay engine from presentation, make the output reproducible from versioned source inputs, add tests to CI, then connect the view to a refreshed artifact/data source. Do not label this prototype “live” until that connection exists.
