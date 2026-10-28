/*
    Validates the core forensic KPI decomposition:

    Expected KPI | Conditions + Operational Residual = Actual KPI

    Any returned row represents a reconciliation failure.
*/

select
    time_bucket,
    facility_id,
    kpi_target_name,
    expected_kpi_given_conditions,
    operational_residual,
    actual_kpi_value
from {{ ref('fct_forensic_kpi_variance') }}
where abs(
    (expected_kpi_given_conditions + operational_residual)
    - actual_kpi_value
) > 0.000001