select
    time_bucket,
    facility_id,
    target_kpi_value,
    work_available_units,
    effective_capacity_units,
    attainable_ceiling,
    kpi_operationally_attainable
from {{ ref('fct_kpi_attainability') }}
where
       (
            kpi_operationally_attainable = true
            and attainable_ceiling < target_kpi_value
       )
    or (
            kpi_operationally_attainable = false
            and attainable_ceiling >= target_kpi_value
       )