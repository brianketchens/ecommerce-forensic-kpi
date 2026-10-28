{{ config(materialized='view') }}

select

    cast(incident_id as varchar) as incident_id,
    cast(facility_id as varchar) as facility_id,

    cast(incident_type as varchar) as incident_type,
    cast(severity as varchar) as severity,
    cast(root_cause as varchar) as root_cause,
    cast(capacity_reduction_pct as numeric) as capacity_reduction_pct,

    cast(t0_genesis as timestamp) as t0_genesis,
    cast(t1_detection as timestamp) as t1_detection,
    cast(t2_escalation as timestamp) as t2_escalation,
    cast(t3_intervention as timestamp) as t3_intervention,
    cast(t4_pil as timestamp) as t4_pil,
    cast(t5_recovery as timestamp) as t5_recovery

from {{ source('raw_data', 'raw_incident_logs') }}