{{
    config(
        materialized='table',
        tags=['mart', 'fact', 'originations']
    )
}}

with originations as (

    select * from {{ ref('stg_naranja_raw__originations') }}

),

applications as (

    select
        application_id,
        channel,
        requested_amount_ars,
        application_date,
        decision_date,
        days_to_decision
    from {{ ref('stg_naranja_raw__applications') }}

),

final as (

    select

        o.origination_id,
        o.customer_id,
        o.product_code,
        o.application_id,
        a.channel as origination_channel,
        o.term_months,
        
        --Métricas financieras
        o.approved_amount_ars,
        a.requested_amount_ars,
        round(o.approved_amount_ars / nullif(a.requested_amount_ars, 0), 4) as approval_ratio,
        o.annual_interest_rate_pct,
        o.monthly_interest_rate_pct,
        o.estimated_monthly_installment_ars,

        --Contexto temporal
        a.application_date,
        a.decision_date,
        o.origination_date,
        o.first_payment_due_date,
        o.origination_cohort,
        a.days_to_decision,
        date_diff(o.origination_date, a.decision_date, day) as days_decision_to_origination,

        current_timestamp() as dbt_updated_at

    from originations o
    left join applications a
        on o.application_id = a.application_id

)

select * from final