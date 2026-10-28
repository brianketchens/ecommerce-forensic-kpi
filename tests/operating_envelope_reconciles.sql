with envelope as (
    select *
    from {{ ref('fct_operating_envelope') }}
),
violations as (
    select
        time_bucket,
        facility_id
    from envelope
    where
        effective_capacity_units > labor_capacity_units
        or effective_capacity_units > staging_capacity_units
        or (
            opening_backlog_units
            + incoming_demand_units
            - physical_throughput_units
            - closing_backlog_units
        ) <> 0
        or physical_throughput_units > work_available_units
        or physical_throughput_units > effective_capacity_units
)
select *
from violations