{{ config(materialized='view') }}

select

    cast(order_item_id as integer) as order_item_id,
    cast(order_id as integer) as order_id,
    cast(product_id as integer) as product_id,
    cast(quantity as integer) as quantity

from {{ source('raw_data', 'raw_order_items') }}