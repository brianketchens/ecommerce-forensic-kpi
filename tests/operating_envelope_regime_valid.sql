select *
from {{ ref('fct_operating_envelope') }}
where operating_regime not in (
    'Demand-Limited',
    'Labor-Bound',
    'Staging-Bound',
    'Incident-Adjusted',
    'Capacity-Bound'
)