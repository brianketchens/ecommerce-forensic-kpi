select *
from {{ ref('fct_kpi_attainability') }}
where attainability_status not in (
    'Attained',
    'Potential Execution Gap',
    'Demand Insufficient',
    'Capacity Insufficient',
    'Demand and Capacity Insufficient'
)