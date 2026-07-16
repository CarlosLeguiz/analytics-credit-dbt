{{
    config(
        materialized='view',
        tags=['intermediate', 'finance', 'customers']
    )
}}

with customers as (

    select * from {{ ref('stg_naranja_raw__customers') }}

),

bureau as (

    select * from {{ ref('stg_naranja_raw__credit_bureau') }}

),

joined as (

    select
        c.customer_id,
        c.full_name,
        c.email,
        c.city,
        c.birth_date,
        date_diff(current_date(), c.birth_date, year) as age_years,
        c.monthly_income_ars,
        c.employment_status,
        c.customer_segment,
        c.signup_date,
        date_diff(current_date(), c.signup_date, day) as days_since_signup,
        c.account_status,
        b.bureau_score,
        b.bureau_risk_tier,
        b.active_debts_count,
        b.total_debt_ars,
        b.delinquencies_last_12m,
        b.has_default_history,
        case
            when b.customer_id is not null then true
            else false
        end as has_bureau_report, --tiene data de bureau? 
        case
            when b.total_debt_ars is not null and c.monthly_income_ars > 0
            then round(b.total_debt_ars / (c.monthly_income_ars * 12), 4)
            else null
        end as debt_to_annual_income_ratio,
        current_timestamp() as dbt_loaded_at
    from customers c
    left join bureau b
        on c.customer_id = b.customer_id

)

select * from joined