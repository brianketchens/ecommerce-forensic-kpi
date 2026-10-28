{{ config(materialized='view') }}

/*
    Unpivots hourly raw operational factor observations (headcount, staging capacity)
    into a standardized factor-key format for downstream beta-coefficient matching.
*/

with source as (
    select * from {{ source('raw_data', 'raw_kpi_telemetry') }}
),

unpivoted as (
    select
        cast(time_bucket as timestamp)      as time_bucket,
        cast(facility_id as varchar)        as facility_id,
        'headcount'                         as operational_factor,
        cast(headcount_observed as numeric) as actual_observed_value
    from source

    union all

    select
        cast(time_bucket as timestamp)      as time_bucket,
        cast(facility_id as varchar)        as facility_id,
        'staging_capacity'                  as operational_factor,
        cast(capacity_observed as numeric)  as actual_observed_value
    from source
)

select * from unpivoted