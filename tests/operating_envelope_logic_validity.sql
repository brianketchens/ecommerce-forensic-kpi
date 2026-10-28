with expected as (

    select
        time_bucket,
        facility_id,
        binding_constraint,
        effective_capacity_units,
        labor_capacity_units,
        staging_capacity_units,

        case
            when effective_capacity_units < labor_capacity_units
                then 'Staging'

            when effective_capacity_units <= staging_capacity_units
                then 'Labor'

            else 'None'
        end as expected_binding_constraint

    from {{ ref('fct_operating_envelope') }}

)

select
    time_bucket,
    facility_id,
    binding_constraint,
    expected_binding_constraint,
    effective_capacity_units,
    labor_capacity_units,
    staging_capacity_units

from expected

where binding_constraint <> expected_binding_constraint