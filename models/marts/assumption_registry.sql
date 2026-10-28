{{ config(
    materialized='table',
    schema='marts'
) }}

/*
    Assumption Registry Dimension Table
    Encapsulates operational assumptions, expected baseline states, impact
    coefficients (beta), and variance classifications.
*/

with assumptions_seed as (
    select * from {{ ref('seed_operational_assumptions') }}
),

transformed as (
    select
        cast(assumption_id as varchar)           as assumption_id,
        cast(kpi_target_name as varchar)        as kpi_target_name,
        cast(operational_factor as varchar)     as operational_factor,
        cast(expected_baseline_value as numeric) as expected_baseline_value,
        cast(impact_coefficient as numeric)     as impact_coefficient, -- Operational impact coefficient (Beta) for KPI variance decomposition
        cast(unit_of_measure as varchar)        as unit_of_measure,
        cast(variance_class as varchar)         as variance_class,       -- 'Avoidable' or 'Unavoidable'
        cast(is_active as boolean)              as is_active,
        current_timestamp                       as updated_at
    from assumptions_seed
)

select * from transformed
where is_active = true
