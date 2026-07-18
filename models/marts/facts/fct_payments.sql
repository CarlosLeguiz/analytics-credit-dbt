{{
    config(
        materialized='incremental',
        unique_key='payment_id',
        incremental_strategy='merge',
        tags=['mart', 'fact', 'payments'],
        partition_by={
            "field": "payment_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['bucket_code', 'customer_sk', 'due_date'],
        on_schema_change='append_new_columns'
    )
}}

with payments as (

    select * from {{ ref('int_payments_delinquency') }}

    {% if is_incremental() %}
        where payment_date >= (
            select date_sub(max(payment_date), interval 3 day)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        
        {{ generate_customer_sk() }} as customer_sk, --sk para consistencia

        --key naturales
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