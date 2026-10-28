{{ config(
    materialized='table',
    schema='marts'
) }}

/*
    Calculates operational response latencies across the T0-T5 timeline
    and flags PIL (Point of Irreversible Loss) SLA breaches.
*/

with incident_logs as (
    select * from {{ ref('stg_incident_logs') }}
),

calculated_metrics as (
    select
        incident_id,
        facility_id,
        incident_type,
        severity,
        root_cause,
        capacity_reduction_pct,

        t0_genesis,
        t1_detection,
        t2_escalation,
        t3_intervention,
        t4_pil,
        t5_recovery,

        round(
            cast(extract(epoch from (t1_detection - t0_genesis)) / 60.0 as numeric),
            2
        ) as detection_latency_minutes,

        round(
            cast(extract(epoch from (t2_escalation - t1_detection)) / 60.0 as numeric),
            2
        ) as escalation_lag_minutes,

        round(
            cast(extract(epoch from (t3_intervention - t1_detection)) / 60.0 as numeric),
            2
        ) as detection_to_intervention_minutes,

        round(
            cast(extract(epoch from (t3_intervention - t0_genesis)) / 60.0 as numeric),
            2
        ) as total_intervention_latency_minutes,

        round(
            cast(extract(epoch from (t4_pil - t0_genesis)) / 60.0 as numeric),
            2
        ) as window_to_pil_minutes,

        round(
            cast(extract(epoch from (t5_recovery - t0_genesis)) / 60.0 as numeric),
            2
        ) as total_recovery_duration_minutes,

        case
            when t3_intervention > t4_pil then true
            else false
        end as is_pil_breached

    from incident_logs
),

final as (
    select
        *,
        case
            when is_pil_breached
                then 'PIL Breach (Late Intervention)'
            else 'Successful Pre-PIL Intervention'
        end as incident_response_status,

        round(
            cast(
                window_to_pil_minutes - total_intervention_latency_minutes
                as numeric
            ),
            2
        ) as pil_buffer_margin_minutes

    from calculated_metrics
)

select * from final