{{ config(materialized='view') }}

select

    cast(time_bucket as timestamp) as time_bucket,
    cast(facility_id as varchar) as facility_id,

    cast(incoming_orders as integer) as incoming_orders,
    cast(incoming_demand_units as integer) as incoming_demand_units,

    cast(opening_backlog_units as integer) as opening_backlog_units,
    cast(units_picked as integer) as units_picked,
    cast(closing_backlog_units as integer) as closing_backlog_units,

    cast(incident_id as varchar) as incident_id

from {{ source('raw_data', 'raw_hourly_demand') }}