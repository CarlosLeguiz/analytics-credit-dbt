{{
    config(
        materialized='view',
        tags=['staging', 'naranja_raw', 'credit_bureau']
    )
}}

with source as (

    select * from {{ source('naranja_raw', 'raw_credit_bureau') }}

),

renamed as (

    select
        customer_id,
        cast(bureau_score as int64) as bureau_score,
        cast(active_debts_count as int64) as active_debts_count,
        cast(total_debt_ars as numeric) as total_debt_ars,
        cast(delinquencies_last_12m as int64) as delinquencies_last_12m,
        cast(has_default_history as boolean) as has_default_history,
        case
            when bureau_score >= 750 then 'PRIME'
            when bureau_score >= 650 then 'NEAR_PRIME'
            when bureau_score >= 550 then 'SUBPRIME'
            else 'DEEP_SUBPRIME'
        end as bureau_risk_tier,
        cast(report_date as date) as report_date,
        current_timestamp() as dbt_loaded_at
    from source

)

select * from renamed