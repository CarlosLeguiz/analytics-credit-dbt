{{
    config(
        materialized='table',
        tags=['mart', 'fact', 'payments'],
        partition_by={
            "field": "due_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=['bucket_code']
    )
}}

with payments as (

    select * from {{ ref('int_payments_delinquency') }}

),

final as (

    select
        
        payment_id,
        origination_id,
        customer_id,

        --Atributos del pago
        installment_number,
        payment_method,
        bucket_code,
        bucket_name,
        is_delinquent_payment,
        is_on_time_payment,
        severity_order,

        --Mora
        days_past_due,

        --Metricas financieras
        due_amount_ars,
        paid_amount_ars,
        payment_variance_ars,

        --Contexto temporal
        due_date,
        payment_date,
        current_timestamp() as dbt_updated_at 

    from payments

)

select * from final