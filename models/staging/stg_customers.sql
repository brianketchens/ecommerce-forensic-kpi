{{ config(materialized='view') }}

select

    cast(customer_id as integer) as customer_id,
    cast(customer_name as varchar) as customer_name,
    cast(region as varchar) as region

from {{ source('raw_data', 'raw_customers') }}