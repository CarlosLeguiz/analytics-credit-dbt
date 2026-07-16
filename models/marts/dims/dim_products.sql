{{
    config(
        materialized='table',
        tags=['mart', 'dim', 'products']
    )
}}

with products as (

    select * from {{ ref('catalog_products') }}

),

final as (

    select

        product_code,
        product_name,
        product_type,
        risk_tier,

        --Limites del producto
        min_amount_ars,
        max_amount_ars,
        max_term_months,

        --Flag: es revolving? 
        case
            when product_type = 'revolving' then true
            else false
        end as is_revolving,
        current_timestamp() as dbt_updated_at

    from products

)

select * from final