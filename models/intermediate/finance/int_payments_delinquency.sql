{{
    config(
        materialized='view',
        tags=['intermediate', 'finance', 'payments']
    )
}}

with payments as (

    select * from {{ ref('stg_naranja_raw__payments') }}

),

buckets as (

    select * from {{ ref('catalog_delinquency_buckets') }}

),

classified as (

    select

        p.payment_id,
        p.origination_id,
        p.customer_id,
        p.installment_number,

        --Fechas y montos
        p.due_date,
        p.payment_date,
        p.due_amount_ars,
        p.paid_amount_ars,
        p.payment_variance_ars,
        p.payment_method,

        --Metricas de mora
        p.days_past_due,
        p.is_on_time_payment,

        --Clasificacion de bucket (viene del seed catalog)
        b.bucket_code,
        b.bucket_name,
        b.is_delinquent,
        b.severity_order,

        --Flag simplificado: fue pago con mora?
        case
            when b.is_delinquent = 'Y' then true
            else false
        end as is_delinquent_payment,
        current_timestamp() as dbt_loaded_at
    from payments p
    inner join buckets b
        on p.days_past_due between b.dpd_min and b.dpd_max --unimos por RANGO, no por igualdad

)

select * from classified