{{ config(materialized='view') }}

select

    cast(order_id as integer) as order_id,
    cast(customer_id as integer) as customer_id,

    cast(order_placed_at as timestamp) as order_placed_at,
    cast(requested_pickup_at as timestamp) as requested_pickup_at,
    cast(actual_picked_at as timestamp) as actual_picked_at,

    cast(is_expedited as boolean) as is_expedited,
    cast(status as varchar) as status,

    cast(units_required as integer) as units_required,
    cast(actual_pick_delay_mins as numeric) as actual_pick_delay_mins,
    cast(sla_variance_mins as numeric) as sla_variance_mins,

    cast(order_placed_at as date) as order_date,
    extract(hour from cast(order_placed_at as timestamp))::integer as order_hour

from {{ source('raw_data', 'raw_orders') }}