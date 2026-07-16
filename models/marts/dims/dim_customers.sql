{{
    config(
        materialized='table',
        tags=['mart', 'dim', 'customers']
    )
}}

with customers_enriched as (

    select * from {{ ref('int_customers_enriched') }}

),

final as (

    select

        customer_id,
        full_name,
        email,
        city,
        birth_date,
        age_years,
        case
            when age_years < 25 then '18-24'
            when age_years < 35 then '25-34'
            when age_years < 45 then '35-44'
            when age_years < 55 then '45-54'
            else '55+'
        end as age_group,
        monthly_income_ars,
        employment_status,
        customer_segment,
        case
            when monthly_income_ars < 500000 then 'LOW'
            when monthly_income_ars < 1500000 then 'MID'
            when monthly_income_ars < 3000000 then 'HIGH'
            else 'PREMIUM'
        end as income_tier,
        signup_date,
        days_since_signup,
        account_status,
        --bureau
        has_bureau_report,
        bureau_score,
        bureau_risk_tier,
        active_debts_count,
        total_debt_ars,
        delinquencies_last_12m,
        has_default_history,
        debt_to_annual_income_ratio,
        current_timestamp() as dbt_updated_at
    from customers_enriched

)

select * from final