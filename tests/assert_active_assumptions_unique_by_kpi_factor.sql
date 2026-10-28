select
    kpi_target_name,
    operational_factor,
    count(*) as assumption_count
from {{ ref('assumption_registry') }}
group by
    kpi_target_name,
    operational_factor
having count(*) > 1