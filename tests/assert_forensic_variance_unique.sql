-- tests/assert_forensic_kpi_variance_unique.sql

select
    facility_id,
    time_bucket,
    kpi_target_name,
    count(*) as row_count
from {{ ref('fct_forensic_kpi_variance') }}
group by
    facility_id,
    time_bucket,
    kpi_target_name
having count(*) > 1