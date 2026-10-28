-- tests/assert_incident_response_status_matches_pil.sql

select *
from {{ ref('fct_incident_response_forensics') }}
where
    (is_pil_breached = true
        and incident_response_status <> 'PIL Breach (Late Intervention)')
    or
    (is_pil_breached = false
        and incident_response_status <> 'Successful Pre-PIL Intervention')