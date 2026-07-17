/*
    scd_credit_bureau — SCD Type 2 snapshot del bureau externo
    
    Propósito:
        Preserva la evolución histórica de los datos del bureau de crédito
        para cada cliente. Cada actualización del bureau (score, tier,
        DTI) genera una nueva versión, cerrando la anterior.
    
    Fuente:
        raw_naranja.raw_credit_bureau (source cruda del vendor externo).
    
    
    Uso strategy = timestamp con report_date como updated_at
    
    Consumidores:
        - int_customers_enriched (join con stg_customers para dim_customers)
        - fct_credit_score_snapshot (PR #6, análisis de evolución mensual)
*/

{% snapshot scd_credit_bureau %}

    {{
        config(
            target_schema='snapshots',
            unique_key='customer_id',
            strategy='timestamp',
            updated_at='report_date',
            invalidate_hard_deletes=True
        )
    }}

    select
        customer_id,
        bureau_score,
        total_debt_ars,
        active_debts_count,
        delinquencies_last_12m,
        has_default_history,
        timestamp(report_date) as report_date
    from {{ source('naranja_raw', 'raw_credit_bureau') }}

{% endsnapshot %}