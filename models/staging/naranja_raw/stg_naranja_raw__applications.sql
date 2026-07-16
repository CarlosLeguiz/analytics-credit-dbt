{{
    config(
        materialized='view',
        tags=['staging', 'naranja_raw', 'applications']
    )
}}

with source as (

    select * from {{ source('naranja_raw', 'raw_applications') }}

),

renamed as (

    select
        application_id,
        customer_id,
        product_code,
        cast(requested_amount_ars as numeric) as requested_amount_ars,
        channel,
        application_status,
        cast(application_date as date) as application_date,
        cast(decision_date as date) as decision_date,
        case
            when decision_date is not null
            then date_diff(cast(decision_date as date), cast(application_date as date), day)
            else null
        end as days_to_decision,
        case when application_status = 'approved' then true else false end as is_approved,
        case when application_status = 'rejected' then true else false end as is_rejected,
        case when application_status = 'pending'  then true else false end as is_pending,
        current_timestamp() as dbt_loaded_at
    from source

)

select * from renamed