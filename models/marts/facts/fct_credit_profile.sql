{{
    config(
        materialized='table',
        tags=['mart', 'fact', 'credit_profile']
    )
}}

with customers as (

    select * from {{ ref('dim_customers') }}

),

applications_summary as (

    -- Agregamos: cuantas solicitudes hizo cada cliente y como le fue
    select
        customer_id,
        count(*) as total_applications,
        sum(case when is_approved then 1 else 0 end) as approved_applications,
        sum(case when is_rejected then 1 else 0 end) as rejected_applications,
        sum(case when is_pending then 1 else 0 end) as pending_applications,
        min(application_date) as first_application_date,
        max(application_date) as last_application_date
    from {{ ref('fct_applications') }}
    group by customer_id

),

originations_summary as (

    -- Agregamos: cuantos creditos activos tiene el cliente y sus totales
    select
        customer_id,
        count(*) as total_originations,
        sum(approved_amount_ars) as total_credit_granted_ars,
        avg(approved_amount_ars) as avg_ticket_ars,
        avg(annual_interest_rate_pct) as avg_interest_rate_pct,
        min(origination_date) as first_origination_date,
        max(origination_date) as last_origination_date
    from {{ ref('fct_originations') }}
    group by customer_id

),

payments_summary as (

    -- Agregamos: comportamiento de pago del cliente
    select
        customer_id,
        count(*) as total_payments,
        sum(case when is_on_time_payment then 1 else 0 end) as on_time_payments,
        sum(case when is_delinquent_payment then 1 else 0 end) as delinquent_payments,
        avg(days_past_due) as avg_days_past_due,
        max(days_past_due) as max_days_past_due,
        max(severity_order) as worst_bucket_ever
    from {{ ref('fct_payments') }}
    group by customer_id

),

final as (

    select
        --PK: 1 fila por cliente
        c.customer_id,

        c.full_name,
        c.age_years,
        c.age_group,
        c.city,
        c.customer_segment,
        c.income_tier,
        c.monthly_income_ars,
        c.account_status,
        c.days_since_signup,

        --bureau
        c.has_bureau_report,
        c.bureau_score,
        c.bureau_risk_tier,
        c.debt_to_annual_income_ratio,
        c.has_default_history,

        --solicitudes
        coalesce(a.total_applications, 0) as total_applications,
        coalesce(a.approved_applications, 0) as approved_applications,
        coalesce(a.rejected_applications, 0) as rejected_applications,
        case
            when coalesce(a.total_applications, 0) > 0
            then round(a.approved_applications / a.total_applications, 4)
            else null
        end as approval_rate,

        --creditos
        coalesce(o.total_originations, 0) as total_originations,
        coalesce(o.total_credit_granted_ars, 0) as total_credit_granted_ars,
        o.avg_ticket_ars,
        o.avg_interest_rate_pct,
        o.first_origination_date,
        o.last_origination_date,

        --aprobados que se convirtieron
        case
            when coalesce(a.approved_applications, 0) > 0
            then round(o.total_originations / a.approved_applications, 4)
            else null
        end as take_rate,

        --Comportamiento de pago
        coalesce(p.total_payments, 0) as total_payments,
        coalesce(p.on_time_payments, 0) as on_time_payments,
        coalesce(p.delinquent_payments, 0) as delinquent_payments,
        case
            when coalesce(p.total_payments, 0) > 0
            then round(p.on_time_payments / p.total_payments, 4)
            else null
        end as on_time_payment_rate,
        p.avg_days_past_due,
        p.max_days_past_due,

        --Perfil de riesgo derivado -> regla de negocio
        case
            when p.max_days_past_due >= 180 then 'DEFAULT'
            when p.max_days_past_due >= 90 then 'HIGH_RISK'
            when p.max_days_past_due >= 30 then 'MEDIUM_RISK'
            when p.max_days_past_due >= 1 then 'LOW_RISK'
            when p.total_payments > 0 then 'CURRENT'
            else 'NO_HISTORY'
        end as current_risk_status,

        --Flag ejecutivo: es un cliente rentable y sano?
        case
            when coalesce(o.total_originations, 0) > 0
                 and coalesce(p.delinquent_payments, 0) = 0
                 and c.account_status = 'active'
            then true
            else false
        end as is_healthy_active_customer,

        current_timestamp() as dbt_updated_at --metadata

    from customers c
    left join applications_summary a on c.customer_id = a.customer_id
    left join originations_summary o on c.customer_id = o.customer_id
    left join payments_summary p on c.customer_id = p.customer_id

)

select * from final