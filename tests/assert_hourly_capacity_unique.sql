-- tests/assert_hourly_capacity_unique.sql

select
    date,
    hour,
    count(*) as row_count
from {{ ref('stg_hourly_capacity') }}
group by date, hour
having count(*) > 1