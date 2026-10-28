-- tests/assert_hourly_demand_unique.sql

select
    facility_id,
    time_bucket,
    count(*) as row_count
from {{ ref('stg_hourly_demand') }}
group by facility_id, time_bucket
having count(*) > 1