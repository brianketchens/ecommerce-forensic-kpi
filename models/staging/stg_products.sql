{{ config(materialized='view') }}

select

    cast(product_id as integer) as product_id,
    cast(sku as varchar) as sku,
    cast(category as varchar) as category,
    cast(unit_price as numeric(10,2)) as unit_price

from {{ source('raw_data', 'raw_products') }}