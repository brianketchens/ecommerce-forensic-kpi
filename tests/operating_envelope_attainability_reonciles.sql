select
    time_bucket,
    facility_id,
    work_available_units,
    effective_capacity_units,
    physical_throughput_units,
    attainable_ceiling
from {{ ref('fct_kpi_attainability') }}
where physical_throughput_units > attainable_ceiling