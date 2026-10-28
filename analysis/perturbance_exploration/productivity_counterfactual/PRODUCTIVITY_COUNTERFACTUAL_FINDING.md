# Static Productivity Counterfactual — Finding

## Question

With the frozen KPI target, demand/work availability, staffing, incident effects, and staging capacity held constant, what happens to KPI attainability when labor-derived capacity is reduced by a controlled productivity multiplier?

## Design

- Input: the exported 720-hour `fct_kpi_attainability` baseline (`Pasted text(3).txt`).
- Baseline productivity: 110 units per labor-hour, as represented by the frozen model's labor-capacity fields.
- Scenario multipliers: 1.00 down to 0.70 in 0.01 increments.
- Only labor-derived, incident-adjusted capacity is multiplied. The staging ceiling remains unchanged.
- Frozen fields: `target_kpi_value`, `work_available`, staffing, `capacity_reduction_pct`, and `staging_capacity`.
- Fixed cohort: the 43 baseline hours with `work_available >= target_kpi_value`. The cohort is defined once from the baseline and does not change by scenario.
- Attainability: `min(work_available, scenario_effective_capacity) >= frozen target_kpi_value`.
- This is a **static hourly counterfactual**, not a dynamic simulation replay. It does not propagate scenario throughput changes into later hours' backlog.

Scenario capacity calculation:

```python
scenario_incident_adjusted_labor_capacity = (
    baseline_incident_adjusted_labor_capacity * productivity_multiplier
)
scenario_effective_capacity = min(
    scenario_incident_adjusted_labor_capacity,
    frozen_staging_capacity,
)
```

At multiplier 1.00, reconstructed effective capacity exactly matches the exported baseline for all 720 rows. The run validates 720 unique hourly rows, 43 fixed-cohort hours, and 7 baseline-attainable hours.

## Result

The test **does not produce a gradual KPI-attainability resilience curve**. It confirms the baseline's zero-downward-tolerance boundary:

| Productivity multiplier | Productivity change | KPI-attainable hours in fixed 43-hour cohort | Attainability |
|---:|---:|---:|---:|
| 1.00 | 0% | 7 / 43 | 16.3% |
| 0.99 | -1% | 0 / 43 | 0.0% |
| 0.98 | -2% | 0 / 43 | 0.0% |
| 0.95 | -5% | 0 / 43 | 0.0% |
| 0.90 | -10% | 0 / 43 | 0.0% |
| 0.80 | -20% | 0 / 43 | 0.0% |
| 0.70 | -30% | 0 / 43 | 0.0% |

All seven baseline-attainable hours have effective capacity exactly equal to the frozen KPI target. Even a 1% productivity reduction moves each below target. The remaining 36 hours in the fixed cohort were already below target at baseline.

Average capacity margin against the frozen target across the 43-hour cohort moves from -154.5 units at baseline to -161.4 units at -1%, and continues to decline with each step. That continuous movement in capacity margin is real, but it does not translate into a continuous attainability curve because the baseline has no positive capacity slack in its seven attainable hours.

## Interpretation

The result is a model-structure finding, not evidence that real operations universally have zero productivity tolerance. In this simulation, the KPI target is tied to nominal labor capacity, leaving no positive capacity margin in the hours that attain it. The counterfactual exposes that boundary; it does not justify changing the baseline to manufacture a smoother curve.

This also reinforces the distinction between:

- **KPI attainability:** Was there enough work and effective capacity to meet the target?
- **Execution:** Given an attainable target, did observed throughput use the available operating envelope?

The static test answers the first question only. It cannot estimate how a sustained productivity reduction would compound into future backlog, order completion, or SLA outcomes. A later dynamic replay would be a separate experiment and should use a verified baseline generator or an explicit replay engine, without replacing the frozen baseline.

## Data-quality note

The frozen export contains 30 rows at 04:00 where `target_kpi_value` does not equal `scheduled_headcount × 110`. These rows have no work available and therefore fall outside the fixed 43-hour demand-present cohort. They were left unchanged rather than silently corrected as part of this counterfactual. They should remain a separately tracked baseline integrity issue.

## Artifacts

- `run_static_productivity_counterfactual.py` — reproducible analysis script.
- `static_productivity_sensitivity_summary.csv` — one row per multiplier.
- `static_productivity_sensitivity_hourly.csv` — scenario-level hourly results for all 720 hours.
- `Pasted text(3).txt` — frozen source export used for the test.
