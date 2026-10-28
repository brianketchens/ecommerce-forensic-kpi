{{ config(
    materialized='table',
    schema='marts'
) }}

with base as (

    select
        oe.time_bucket,
        oe.facility_id,

        oe.shift,
        oe.scheduled_headcount,
        oe.actual_headcount,
        oe.call_offs,

        kt.kpi_target_name,
        kt.target_kpi_value,
        kt.actual_kpi_value as telemetric_kpi_value,

        oe.incoming_orders,
        oe.incoming_demand_units,
        oe.opening_backlog_units,
        oe.work_available_units,
        oe.physical_throughput_units,
        oe.closing_backlog_units,

        oe.labor_capacity_units,
        oe.staging_capacity_units,
        oe.effective_capacity_units,

        oe.capacity_headroom_units,
        oe.workload_pressure_pct,

        oe.binding_constraint,
        oe.operating_regime,
        oe.incident_id

    from {{ ref('fct_operating_envelope') }} oe

    left join {{ ref('stg_kpi_telemetry') }} kt
        on oe.time_bucket = kt.time_bucket
        and oe.facility_id = kt.facility_id
        and kt.kpi_target_name = 'picked_units_per_hour'

),

derived as (

    select
        *,

        /*
        The maximum KPI output physically available under
        the observed workload and operating capacity.
        */
        least(
            work_available_units,
            effective_capacity_units
        ) as attainable_ceiling,

        /*
        A KPI target is operationally attainable only when
        both sufficient work and sufficient effective capacity
        exist to reach the target.
        */
        case
            when least(
                work_available_units,
                effective_capacity_units
            ) >= target_kpi_value
                then true
            else false
        end as kpi_operationally_attainable,

        /*
        Distinguish the two reasons a target may be unattainable.
        */
        case
            when work_available_units < target_kpi_value
                then true
            else false
        end as demand_insufficient_for_kpi,

        case
            when effective_capacity_units < target_kpi_value
                then true
            else false
        end as capacity_insufficient_for_kpi,

        /*
        Physical operation reached everything the observed
        conditions allowed it to produce.
        */
        case
            when physical_throughput_units >= least(
                work_available_units,
                effective_capacity_units
            )
                then true
            else false
        end as operation_reached_attainable_ceiling,

        /*
        Target was attainable but observed physical throughput
        did not reach the target.
        */
        case
            when least(
            work_available_units,
            effective_capacity_units
            ) >= target_kpi_value

            and physical_throughput_units < target_kpi_value

            and physical_throughput_units
                < least(
                    work_available_units,
                    effective_capacity_units
                    )

                then true
            else false
    end as potential_execution_gap

    from base

),

classified as (

    select
        *,

        case

            when not kpi_operationally_attainable
                and demand_insufficient_for_kpi
                and capacity_insufficient_for_kpi
                then 'Demand and Capacity Insufficient'

            when not kpi_operationally_attainable
                and demand_insufficient_for_kpi
                then 'Demand Insufficient'

            when not kpi_operationally_attainable
                and capacity_insufficient_for_kpi
                then 'Capacity Insufficient'

            when potential_execution_gap
                then 'Potential Execution Gap'

            when kpi_operationally_attainable
                and operation_reached_attainable_ceiling
                and physical_throughput_units >= target_kpi_value
                then 'Attained'

            when kpi_operationally_attainable
                and operation_reached_attainable_ceiling
                then 'Attained at Capacity Ceiling'

            else 'Unclassified'

end as attainability_status

    from derived

)

select
    *
from classified