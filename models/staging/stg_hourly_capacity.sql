{{ config(materialized='view') }}

select

    cast(date as date) as date,
    cast(hour as integer) as hour,

    cast(system_capacity_limit as integer) as system_capacity_limit,
    cast(actual_capacity_limit as integer) as actual_capacity_limit,

    cast(constraint_reason as varchar) as constraint_reason,

    cast(capacity_reduction_pct as numeric) as capacity_reduction_pct,

    cast(incident_id as varchar) as incident_id

from {{ source('raw_data', 'raw_hourly_capacity') }}