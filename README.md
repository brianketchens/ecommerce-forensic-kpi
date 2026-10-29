# E-Commerce Operational Forensics: SLA Decision Support

[![Frozen Fixture dbt CI](https://github.com/brianketchens/ecommerce-forensic-kpi/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/brianketchens/ecommerce-forensic-kpi/actions/workflows/dbt_ci.yml)

An operational BI prototype for examining service-level agreement (SLA) performance, diagnosing backlog risk, and evaluating interventions against a controlled baseline.

**The business question:** When order demand, labor capacity, throughput, and backlog interact, which operational changes could reduce SLA misses—and what tradeoffs accompany those changes?

This project combines simulated operational data, PostgreSQL, dbt dimensional modeling, order-level SLA replay, and an interactive decision view to explore that question.

## Explore the project

**[Open the Operational SLA Decision View](https://brianketchens.github.io/ecommerce-forensic-kpi/)**

The self-contained HTML dashboard compares a frozen baseline with four intervention scenarios. It allows visitors to examine service performance, backlog exposure, lateness, and illustrative labor-cost tradeoffs.

To interact with the dashboard, download the HTML file and open it in a modern browser. It does not require a running database or external JavaScript libraries.

The dashboard is a local, interactive prototype using bundled analytical outputs—not a live-connected operational system.

## What the analysis examines

- **SLA performance:** Compare baseline and intervention outcomes under a consistent order-level replay contract.
- **Backlog exposure:** Examine peak queue size, overdue orders, and backlog composition.
- **Operational tradeoffs:** Compare staffing, workload reallocation, staging relief, and productivity sensitivity scenarios.
- **Priority-level outcomes:** Inspect SLA results for expedited and standard orders.
- **Illustrative economics:** Explore labor-cost sensitivity and cost per SLA miss avoided using adjustable hourly labor-rate assumptions.

The scenarios hold the same underlying orders, order sizes, arrival times, deadlines, and KPI target constant. This creates a controlled comparison of modeled interventions rather than a comparison of unrelated operating periods.

## Analytical findings and interpretation

The frozen baseline replay calculates **37 SLA misses**, while the upstream generator labels 117 orders as `Delayed`. These measures are not equivalent: the discrepancy identifies a model-fidelity issue that should be resolved before treating generated status labels as interchangeable with replay-derived SLA outcomes.

The intervention comparisons also require careful interpretation:

- Only the additional-morning-associate scenario includes modeled incremental labor-hours: 240.
- Reallocation, staging relief, and productivity improvement do not include their real implementation costs.
- Staging relief represents an idealized upper-bound scenario.
- Productivity improvement is a sensitivity analysis, not a measured operational gain.

The dashboard is intended to support structured operational reasoning. Its modeled outcomes are not evidence that a particular intervention would produce the same results in a real fulfillment operation.

## Technical architecture

The project separates operational data, transformation, analytical evaluation, and presentation.

1. **Simulated operational data:** Customer, product, order, order-item, shift, hourly demand, capacity, backlog, incident, and KPI records.
2. **PostgreSQL:** Raw operational tables and the database environment used for analytical development.
3. **dbt:** Staging transformations, dimensional modeling, analytical marts, and data-quality tests.
4. **SLA replay and scenario analysis:** A frozen order-level FIFO replay contract and intervention outputs used to compare operational alternatives.
5. **Interactive decision view:** A self-contained HTML dashboard that presents the bundled scenario results.

The intended causal framing is:

**Demand → Labor and capacity → Throughput → Backlog → Order completion → SLA performance**

This structure connects operational measures to the business processes that influence them instead of treating dashboard KPIs as isolated numbers.

## Validation and reproducibility

The repository includes a GitHub Actions workflow that:

- Validates the frozen raw CSV fixture.
- Initializes PostgreSQL in a clean CI environment.
- Loads the project's dbt seed data.
- Builds dbt models and runs their associated tests.

The workflow is designed to validate the existing fixture without regenerating the simulated operational data. This preserves a controlled baseline for testing and analytical comparison.

The CI workflow validates the data and transformation project; it does not establish that the dashboard is deployed, connected to live data, or automatically refreshed from a production system.

## Repository guide

| Location | Purpose |
|---|---|
| `models/` | dbt staging models and analytical transformations |
| `seeds/` | Versioned dbt seed data |
| `tests/` | dbt data-quality and validation tests |
| `scripts/` | Fixture validation and supporting scripts |
| `raw_schema_init.sql` | Raw PostgreSQL schema initialization |
| `raw_*.csv` | Frozen simulated operational data |
| `analysis/operational_decision_view_v1_bundle/` | Dashboard, replay contract, scenario results, validation evidence, and baseline audit |
| `.github/workflows/dbt_ci.yml` | Automated CI validation and dbt build |

### Key analytical artifacts

- [Frozen SLA replay contract](analysis/operational_decision_view_v1_bundle/FROZEN_SLA_REPLAY_CONTRACT_v1.md) — defines the replay rules.
- [Intervention results](analysis/operational_decision_view_v1_bundle/INTERVENTION_RESULTS.md) — summarizes the scenario comparisons and caveats.
- [Baseline replay findings](analysis/operational_decision_view_v1_bundle/BASELINE_REPLAY_FINDINGS.md) — documents the baseline outcomes.
- [Baseline data audit](analysis/operational_decision_view_v1_bundle/BASELINE_DATA_AUDIT.md) — documents the baseline data review.
- [Intervention comparison data](analysis/operational_decision_view_v1_bundle/intervention_scenario_comparison.csv) — provides the primary scenario metrics.
- [Validation checks](analysis/operational_decision_view_v1_bundle/intervention_validation_checks.json) — provides the intervention validation evidence.

## Current scope and next phase

The current version evaluates precomputed scenarios against a frozen replay baseline. It is a decision-support prototype, not a live warehouse dashboard.

The next planned engineering phase is a **live-like operational simulation**: replaying hourly or order-level events over simulated time, updating selected metrics as events arrive, and distinguishing simulated event time from actual dashboard refresh time.

That extension will explore how SLA risk and backlog evolve as an operating scenario unfolds, without implying a connection to a real warehouse.

## Project objective

Demonstrate how operational context, data modeling, controlled scenario analysis, and BI presentation can be combined to evaluate KPI performance and make operational tradeoffs more explicit.