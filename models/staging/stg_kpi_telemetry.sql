{{ config(materialized='view') }}

select

    cast(time_bucket as timestamp) as time_bucket,
    cast(facility_id as varchar) as facility_id,

    cast(kpi_target_name as varchar) as kpi_target_name,
    cast(target_kpi_value as numeric) as target_kpi_value,
    cast(actual_kpi_value as numeric) as actual_kpi_value,

    cast(headcount_observed as numeric) as headcount_observed,
    cast(capacity_observed as numeric) as capacity_observed,

    cast(scheduled_headcount as numeric) as scheduled_headcount,
    cast(labor_capacity_units as numeric) as labor_capacity_units,
    cast(effective_capacity_units as numeric) as effective_capacity_units,

    cast(incoming_demand_units as numeric) as incoming_demand_units,
    cast(opening_backlog_units as numeric) as opening_backlog_units,
    cast(units_picked as numeric) as units_picked,
    cast(closing_backlog_units as numeric) as closing_backlog_units,

    cast(incident_id as varchar) as incident_id

from {{ source('raw_data', 'raw_kpi_telemetry') }}