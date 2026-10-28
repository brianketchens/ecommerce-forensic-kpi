{{ config(materialized='view') }}

select

    cast(date as date) as date,
    cast(shift as varchar) as shift,
    cast(scheduled_headcount as integer) as scheduled_headcount,
    cast(actual_headcount as integer) as actual_headcount,
    cast(call_offs as integer) as call_offs,
    cast(avg_pick_rate_target as numeric) as avg_pick_rate_target

from {{ source('raw_data', 'raw_shift_logs') }}