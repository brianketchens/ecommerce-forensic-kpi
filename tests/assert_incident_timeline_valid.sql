select *

from {{ ref('stg_incident_logs') }}

where not (
       t0_genesis <= t1_detection
   and t1_detection <= t2_escalation
   and t2_escalation <= t3_intervention
   and t3_intervention <= t4_pil
   and t4_pil <= t5_recovery
)