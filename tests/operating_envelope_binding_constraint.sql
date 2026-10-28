select *
from {{ ref('fct_operating_envelope') }}
where binding_constraint not in (
    'Labor',
    'Staging',
    'None'
)