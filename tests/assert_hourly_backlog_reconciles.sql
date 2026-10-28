select *

from {{ ref('stg_hourly_backlog') }}

where
    opening_backlog_units
    + incoming_units
    - picked_units
    <> closing_backlog_units