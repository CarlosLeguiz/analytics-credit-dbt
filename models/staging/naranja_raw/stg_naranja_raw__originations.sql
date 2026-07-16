{{
    config(
        materialized='view',
        tags=['staging', 'naranja_raw', 'originations']
    )
}}

with source as (

    select * from {{ source('naranja_raw', 'raw_originations') }}

),

renamed as (

    select
        origination_id,
        application_id,
        customer_id,
        product_code,
        cast(approved_amount_ars as numeric) as approved_amount_ars,
        cast(term_months as int64) as term_months,
        cast(annual_interest_rate_pct as numeric) as annual_interest_rate_pct,
        round(cast(annual_interest_rate_pct as numeric) / 12, 4) as monthly_interest_rate_pct,
        case
            when term_months > 0 then
                round(
                    cast(approved_amount_ars as numeric) / term_months
                    * (1 + cast(annual_interest_rate_pct as numeric) / 100 / 12),
                    2
                )
            else null
        end as estimated_monthly_installment_ars,
        cast(origination_date as date) as origination_date,
        cast(first_payment_due_date as date) as first_payment_due_date,
        format_date('%Y-%m', cast(origination_date as date)) as origination_cohort,
        current_timestamp() as dbt_loaded_at
    from source

)

select * from renamed