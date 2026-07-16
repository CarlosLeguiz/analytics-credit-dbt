{{
    config(
        materialized='view',
        tags=['staging', 'naranja_raw', 'payments']
    )
}}

with source as (

    select * from {{ source('naranja_raw', 'raw_payments') }}

),

renamed as (

    select
        payment_id,
        origination_id,
        customer_id,
        cast(installment_number as int64) as installment_number,
        cast(due_date as date) as due_date,
        cast(payment_date as date) as payment_date,
        cast(due_amount_ars as numeric) as due_amount_ars,
        cast(paid_amount_ars as numeric) as paid_amount_ars,
        round(
            cast(paid_amount_ars as numeric) - cast(due_amount_ars as numeric),
            2
        ) as payment_variance_ars,  -- Underpayment / overpayment amount (positive = overpaid)
        payment_method,
        date_diff(
            cast(payment_date as date),
            cast(due_date as date),
            day
        ) as days_past_due,
        case
            when cast(payment_date as date) <= cast(due_date as date) then true
            else false
        end as is_on_time_payment,
        current_timestamp() as dbt_loaded_at

    from source

)

select * from renamed