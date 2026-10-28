{{ config(
    materialized='table',
    schema='marts'
) }}

with hourly_operating_state as (

    select
        d.time_bucket,
        d.facility_id,

        -- ----------------------------------------------------
        -- Operating context
        -- ----------------------------------------------------

        sl.shift,
        sl.scheduled_headcount,
        sl.actual_headcount,
        sl.call_offs,
        sl.avg_pick_rate_target,

        -- ----------------------------------------------------
        -- Capacity
        -- ----------------------------------------------------

        c.system_capacity_limit,
        c.actual_capacity_limit as staging_capacity_units,
        c.capacity_reduction_pct,
        c.constraint_reason,

        -- ----------------------------------------------------
        -- Work available
        -- ----------------------------------------------------

        d.incoming_orders,
        d.incoming_demand_units,
        d.opening_backlog_units,

        (
            d.incoming_demand_units
            + d.opening_backlog_units
        ) as work_available_units,

        -- ----------------------------------------------------
        -- Physical result
        -- ----------------------------------------------------

        d.units_picked as physical_throughput_units,
        d.closing_backlog_units,

        -- ----------------------------------------------------
        -- Recorded V2 operating physics
        -- ----------------------------------------------------

        kt.labor_capacity_units,
        kt.effective_capacity_units,

        -- ----------------------------------------------------
        -- Incident context
        -- ----------------------------------------------------

        d.incident_id

    from {{ ref('stg_hourly_demand') }} d

    left join {{ ref('stg_hourly_capacity') }} c
        on d.time_bucket::date = c.date
        and extract(hour from d.time_bucket) = c.hour

    left join {{ ref('stg_shift_logs') }} sl
        on d.time_bucket::date = sl.date
        and (
            (
                d.time_bucket::time >= time '04:00:00'
                and d.time_bucket::time < time '12:00:00'
                and sl.shift = 'Morning'
            )
            or
            (
                d.time_bucket::time >= time '12:00:00'
                and d.time_bucket::time < time '20:00:00'
                and sl.shift = 'Afternoon'
            )
            or
            (
                (
                    d.time_bucket::time >= time '20:00:00'
                    or d.time_bucket::time < time '04:00:00'
                )
                and sl.shift = 'Night'
            )
        )

    left join {{ ref('stg_kpi_telemetry') }} kt
        on d.time_bucket = kt.time_bucket
        and d.facility_id = kt.facility_id
        and kt.kpi_target_name = 'picked_units_per_hour'

),

derived as (

    select
        *,

        (
            effective_capacity_units
            - work_available_units
        ) as capacity_headroom_units,

        case
            when effective_capacity_units > 0
                then (
                    work_available_units
                    / effective_capacity_units
                ) * 100.0
            else null
        end as workload_pressure_pct,

        (
            closing_backlog_units / 30.0
        ) as backlog_order_equivalent,

        -- ----------------------------------------------------
        -- Capacity-envelope constraint
        --
        -- Identifies the resource that limits effective
        -- capacity, independent of current workload.
        -- ----------------------------------------------------

    case
    when effective_capacity_units < labor_capacity_units
        then 'Staging'

    when effective_capacity_units <= staging_capacity_units
        then 'Labor'

    else 'None'
end as binding_constraint,

        -- ----------------------------------------------------
        -- Current operating regime
        -- ----------------------------------------------------

       case
    when work_available_units <= effective_capacity_units
        then 'Demand-Limited'

    when incident_id is not null
        then 'Incident-Adjusted'

    when effective_capacity_units < labor_capacity_units
        then 'Staging-Bound'

    when effective_capacity_units < staging_capacity_units
        then 'Labor-Bound'

    else 'Capacity-Bound'
end as operating_regime

    from hourly_operating_state

)

select
    *
from derived
