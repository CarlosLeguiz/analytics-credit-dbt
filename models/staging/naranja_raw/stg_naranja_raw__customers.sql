{{
    config(
        materialized='view',
        tags=['staging', 'naranja_raw', 'customers']
    )
}}

with source as (

    select * from {{ source('naranja_raw', 'raw_customers') }}

),

renamed as (

    select
        customer_id,
        {{ mask_pii('first_name', 'name') }} as first_name,
        {{ mask_pii('last_name', 'name') }} as last_name,
        concat({{ mask_pii('first_name', 'name') }}, ' ', {{ mask_pii('last_name', 'name') }}) as full_name,
        {{ mask_pii('email', 'email') }} as email,
        {{ mask_pii('cast(phone as string)', 'phone') }} as phone,
        city,
        {{ mask_pii('birth_date', 'birth_date') }} as birth_date,
        cast(monthly_income_ars as numeric) as monthly_income_ars,
        employment_status,
        customer_segment,
        cast(signup_date as date) as signup_date,
        account_status,
        cast(updated_at as timestamp) as source_updated_at,
        current_timestamp() as dbt_loaded_at

    from source

)

select * from renamed