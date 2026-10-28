{{ config(
    materialized='table',
    schema='marts'
) }}

/*
    Forensic KPI Variance Mart
    Decomposes Actual KPI into Target KPI, Unavoidable Delta, Avoidable Delta,
    Conditional Expectation E[KPI | X], and Unexplained Operational Residual (epsilon).
*/

with kpi_actuals as (
    select
        time_bucket,
        facility_id,
        kpi_target_name,
        target_kpi_value,
        actual_kpi_value
    from {{ ref('stg_kpi_telemetry') }}
),

observed_conditions as (
    select
        obs.time_bucket,
        obs.facility_id,
        kpi.kpi_target_name,
        obs.operational_factor,
        obs.actual_observed_value
    from {{ ref('stg_operational_telemetry') }} obs
    inner join {{ ref('stg_kpi_telemetry') }} kpi
        on obs.time_bucket = kpi.time_bucket
       and obs.facility_id = kpi.facility_id
),

assumptions as (
    select * from {{ ref('assumption_registry') }}
),

-- Step 1: Calculate Delta_X and individual factor impacts (Beta * Delta_X)
factor_impacts as (
    select
        obs.time_bucket,
        obs.facility_id,
        asm.kpi_target_name,
        asm.assumption_id,
        asm.operational_factor,
        asm.variance_class,
        asm.impact_coefficient,
        asm.expected_baseline_value,
        obs.actual_observed_value,
        (obs.actual_observed_value - asm.expected_baseline_value) as delta_condition,
        (obs.actual_observed_value - asm.expected_baseline_value) * asm.impact_coefficient as factor_kpi_impact
    from observed_conditions obs
    inner join assumptions asm
    on obs.operational_factor = asm.operational_factor
   and obs.kpi_target_name = asm.kpi_target_name
),

-- Step 2: Aggregate impact deltas by variance classification (Avoidable vs Unavoidable)
aggregated_impacts as (
    select
        time_bucket,
        facility_id,
        kpi_target_name,
        sum(case when variance_class = 'Unavoidable' then factor_kpi_impact else 0 end) as delta_unavoidable,
        sum(case when variance_class = 'Avoidable' then factor_kpi_impact else 0 end)   as delta_avoidable
    from factor_impacts
    group by 1, 2, 3
),

-- Step 3: Compute Conditional Expectation E[KPI | X], Residual, and Variance components
forensic_decomposition as (
    select
        act.time_bucket,
        act.facility_id,
        act.kpi_target_name,
        act.target_kpi_value,
        coalesce(imp.delta_unavoidable, 0) as delta_unavoidable,
        coalesce(imp.delta_avoidable, 0)   as delta_avoidable,

        -- E[KPI | X] = Target + Delta_Unavoidable + Delta_Avoidable
        (act.target_kpi_value
            + coalesce(imp.delta_unavoidable, 0)
            + coalesce(imp.delta_avoidable, 0)) as expected_kpi_given_conditions,

        act.actual_kpi_value,

        -- Operational Residual (epsilon) = Actual - E[KPI | X]
        act.actual_kpi_value - (
            act.target_kpi_value
            + coalesce(imp.delta_unavoidable, 0)
            + coalesce(imp.delta_avoidable, 0)
        ) as operational_residual
    from kpi_actuals act
    left join aggregated_impacts imp
        on act.time_bucket = imp.time_bucket
       and act.facility_id = imp.facility_id
       and act.kpi_target_name = imp.kpi_target_name
),

-- Step 4: Window calculations for Var(X) = E[X^2] - [E[X]]^2 over a 7-bucket rolling window
variance_metrics as (
    select
        *,
        -- Rolling E[Actual]
        avg(actual_kpi_value) over (
            partition by facility_id, kpi_target_name
            order by time_bucket
            rows between 6 preceding and current row
        ) as expected_actual_mean,

        -- Rolling E[Actual^2]
        avg(power(actual_kpi_value, 2)) over (
            partition by facility_id, kpi_target_name
            order by time_bucket
            rows between 6 preceding and current row
        ) as expected_actual_square_mean
    from forensic_decomposition
)

select
    time_bucket,
    facility_id,
    kpi_target_name,
    target_kpi_value,
    delta_unavoidable,
    delta_avoidable,
    expected_kpi_given_conditions,
    actual_kpi_value,
    operational_residual,

    -- Var(X) = E[X^2] - [E[X]]^2
    greatest(0, expected_actual_square_mean - power(expected_actual_mean, 2)) as kpi_variance_rolling
from variance_metrics
