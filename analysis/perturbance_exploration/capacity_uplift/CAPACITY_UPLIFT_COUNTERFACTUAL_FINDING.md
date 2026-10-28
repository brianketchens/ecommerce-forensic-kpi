# Capacity-Uplift Counterfactual — Structural Slack Diagnostic

## Question

If the frozen KPI target, available work, staffing records, incident history, and staging ceilings remain unchanged, what level of additional labor-derived capacity would be required to make the KPI physically attainable in more of the baseline's demand-present hours?

## Why this follows the productivity-degradation test

The downward productivity test established that the seven baseline-attainable hours sit exactly at the target boundary. Degrading capacity by 1% removed all seven. Before undertaking a dynamic replay, this complementary static test estimates how much additional labor-derived capacity would be needed to restore attainability elsewhere in the same baseline population.

This is a **scenario-only capacity-uplift multiplier**, not a change to the baseline generator or a claim that such a productivity improvement is operationally available. It is a diagnostic of the capacity reserve implied by the current model.

## Design

- Input: frozen `fct_kpi_attainability` export, 720 unique hourly rows.
- Scenario multipliers: 1.00 to 1.50, in 0.01 increments.
- Frozen: KPI target, work availability, staffing observations, incident history and reductions, staging capacity.
- Fixed cohort: the 43 baseline hours where `work_available >= target_kpi_value`.
- Scenario capacity: `min(incident_adjusted_labor_capacity × multiplier, staging_capacity)`.
- Attainability: `min(work_available, scenario_effective_capacity) >= frozen target`.
- Static limitation: scenario throughput is not replayed through time, so backlog and later-hour work availability remain at baseline values.

Baseline validation passed: effective capacity reconstructed exactly for all 720 hours; the source had 7 attainable hours; the fixed cohort contained 43 hours and remained fixed in all scenarios.

## Results

| Capacity uplift | Attainable hours in fixed cohort | Attainability |
|---:|---:|---:|
| 0% (baseline) | 7 / 43 | 16.3% |
| +10% | 7 / 43 | 16.3% |
| +15% | 29 / 43 | 67.4% |
| +25% | 29 / 43 | 67.4% |
| +34% | 35 / 43 | 81.4% |
| +40% | 35 / 43 | 81.4% |
| +50% | 37 / 43 | 86.0% |

The result is a **stepwise capacity-requirement curve**, not a smooth resilience curve.

### What drives the steps?

- **+14.3% (first attained on the 1%-grid at +15%)** is enough to lift hours with 7 of 8 scheduled associates from 770 to at least the 880-unit target. Those hours account for the jump from 7 to 29 attainable hours.
- **+33.3% (first attained on the 1%-grid at +34%)** is enough to lift the six non-incident hours with 6 of 8 scheduled associates from 660 to at least 880 units. Attainable hours rise from 29 to 35.
- **+50%** makes the two hours with 2 of 3 scheduled associates reach their 330-unit target, lifting the result to 37 hours.
- **Six hours remain unattainable at any labor multiplier** in this scenario because the incident-adjusted staging ceiling is below the frozen 880-unit target (four hours at 650 units and two at 500 units). More labor-derived capacity cannot overcome that ceiling.

The multiplier is applied to the exported incident-adjusted labor capacity, and the staging ceiling is then enforced. It should be interpreted as an equivalent capacity-uplift requirement, not as a literal claim that individual productivity can or should increase by these percentages.

## Interpretation

This experiment does not uncover hidden slack already present in the baseline. It identifies the **additional capacity margin that would have to exist** to make more of the fixed demand-present hours attainable under the current KPI definition.

The shape is intuitive and decision-relevant:

1. Small capacity increases produce no additional KPI-attainable hours.
2. A +15% uplift crosses the threshold for one-calloff hours.
3. A +34% uplift crosses the threshold for two-calloff hours where staging is not the binding ceiling.
4. Staging-constrained incident hours remain unattainable regardless of labor uplift.

This reinforces the separation between KPI attainability and execution. The counterfactual estimates the capacity side of attainability; it does not assess whether execution used available capacity, nor does it estimate downstream SLA or backlog changes.

## Recommended next step

Preserve both static results as structural findings. Only then decide whether a dynamic replay is worth the additional complexity. If pursued, it should use a verified generator or a dedicated replay engine, freeze the original baseline artifacts, and measure how the capacity intervention changes throughput, backlog propagation, completion, and SLA outcomes over time.

## Artifacts

- `run_capacity_uplift_counterfactual.py` — reproducible scenario script.
- `capacity_uplift_sensitivity_summary.csv` — one row per capacity multiplier.
- `capacity_uplift_sensitivity_hourly.csv` — scenario results for every hour and multiplier.
- `capacity_uplift_thresholds_by_hour.csv` — per-hour required multiplier and staging feasibility.
- `Pasted text(3).txt` — frozen source export used in this run.
