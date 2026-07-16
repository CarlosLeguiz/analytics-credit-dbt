{{
    config(
        materialized='table',
        tags=['mart', 'fact', 'applications']
    )
}}

with applications as (

    select * from {{ ref('int_applications_with_outcome') }}

),

final as (

    select

        application_id,
        customer_id,
        product_code,
        origination_id,
        channel,
        application_status,
        is_approved,
        is_rejected,
        is_pending,
        was_originated,
        approved_not_taken,
        requested_amount_ars,
        approved_amount_ars,
        approval_ratio,
        days_to_decision,
        days_decision_to_origination,
        application_date,
        decision_date,
        origination_date,
        current_timestamp() as dbt_updated_at

    from applications

)

select * from final