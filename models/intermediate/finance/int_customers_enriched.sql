{{
    config(
        materialized='view',
        tags=['intermediate', 'finance', 'customers']
    )
}}

-- Este modelo consolida el perfil actual del cliente uniendo datos demográficos
-- con la última versión del bureau vigente.
-- lee snapshot de SCD Type 2.
-- filtrando por dbt_valid_to IS NULL, que es como se representa "la versión
-- vigente hoy" en el modelo.

with customers as (

    select * from {{ ref('stg_naranja_raw__customers') }}

),

bureau_current as (

    -- Última versión vigente del bureau por cliente.
    -- El snapshot puede tener múltiples versiones por customer_id, pero solo
    -- una tiene dbt_valid_to IS NULL (como mi modelo es teorico opte por esta decision).
    -- para logicas mayores, implementacion de row number o windows functions con mas condiciones
    select
        customer_id,
        bureau_score,
        total_debt_ars,
        active_debts_count,
        delinquencies_last_12m,
        has_default_history
    from {{ ref('scd_credit_bureau') }}
    where dbt_valid_to is null

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

        -- bureau_risk_tier se deriva del score actual del bureau.
        -- Thresholds definidos por Riesgo — si cambian, este case
        -- se actualiza acá sin tocar el snapshot.
        case
            when b.bureau_score is null then null
            when b.bureau_score >= 750 then 'LOW_RISK'
            when b.bureau_score >= 650 then 'MEDIUM_RISK'
            else 'HIGH_RISK'
        end as bureau_risk_tier,

        b.active_debts_count,
        b.total_debt_ars,
        b.delinquencies_last_12m,
        b.has_default_history,

        case
            when b.customer_id is not null then true
            else false
        end as has_bureau_report,

        case
            when b.total_debt_ars is not null and c.monthly_income_ars > 0
            then round(b.total_debt_ars / (c.monthly_income_ars * 12), 4)
            else null
        end as debt_to_annual_income_ratio,

        current_timestamp() as dbt_loaded_at

    from customers c
    left join bureau_current b
        on c.customer_id = b.customer_id

)

select * from joined