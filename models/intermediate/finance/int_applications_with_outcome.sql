{{
    config(
        materialized='view',
        tags=['intermediate', 'finance', 'applications']
    )
}}

with applications as (

    select * from {{ ref('stg_naranja_raw__applications') }}

),

originations as (

    select * from {{ ref('stg_naranja_raw__originations') }}

),

joined as (

    select
        --Datos de la solicitud
        a.application_id,
        a.customer_id,
        a.product_code,
        a.requested_amount_ars,
        a.channel,
        a.application_status,
        a.application_date,
        a.decision_date,
        a.days_to_decision,
        a.is_approved,
        a.is_rejected,
        a.is_pending,

        --Datos de la originacion
        o.origination_id,
        o.approved_amount_ars,
        o.term_months,
        o.annual_interest_rate_pct,
        o.monthly_interest_rate_pct,
        o.estimated_monthly_installment_ars,
        o.origination_date,
        o.first_payment_due_date,
        o.origination_cohort,

        --Flags de negocio
        case
            when o.origination_id is not null then true
            else false
        end as was_originated,

        --Ayuda para calcular take rate: aprobados que no se convirtieron 
        case
            when a.is_approved and o.origination_id is null then true
            else false
        end as approved_not_taken,

        --Lag entre decision y origen efectivo
        case
            when o.origination_date is not null and a.decision_date is not null
            then date_diff(o.origination_date, a.decision_date, day)
            else null
        end as days_decision_to_origination,

        --Ratio ticket: cuanto del monto pedido fue aprobado
        case
            when o.approved_amount_ars is not null and a.requested_amount_ars > 0
            then round(o.approved_amount_ars / a.requested_amount_ars, 4)
            else null
        end as approval_ratio,
        current_timestamp() as dbt_loaded_at
    from applications a
    left join originations o
        on a.application_id = o.application_id

)

select * from joined