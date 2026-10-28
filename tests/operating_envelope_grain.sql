select
    time_bucket,
    facility_id,
    count(*) as row_count
from {{ ref('fct_operating_envelope') }}
group by time_bucket, facility_id
having count(*) <> 1