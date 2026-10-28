{{ config(materialized='view') }}

select

    cast(time_bucket as timestamp) as time_bucket,
    cast(facility_id as varchar) as facility_id,

    cast(opening_backlog_units as integer) as opening_backlog_units,
    cast(incoming_units as integer) as incoming_units,
    cast(picked_units as integer) as picked_units,
    cast(closing_backlog_units as integer) as closing_backlog_units,

    cast(incident_id as varchar) as incident_id

from {{ source('raw_data', 'raw_hourly_backlog') }}