-- rpt_executive_summary: reporting mart mensual para la pagina "Resumen" del
-- dashboard ejecutivo. Grano: (period_month, product_code, customer_segment).
--
-- Power BI es visualizador puro. Todas las metricas base viven
-- aca pre-agregadas. Los ratios (approval rate, delinquency rate, ticket
-- promedio, dpd promedio) se calculan en Power BI con DIVIDE de SUMs para
-- que funcionen correctamente bajo cualquier filter context (mes, quarter,
-- year, YTD, por producto, por segmento).
--
-- Consumidores:
--   - Power BI: pagina "Resumen" del dashboard ejecutivo

{{
    config(
        materialized='table',
        tags=['mart', 'rpt', 'reporting', 'executive']
    )
}}

with

business_range as (
    select
        least(
            (select min(date_trunc(application_date, month)) from {{ ref('fct_applications') }}),
            (select min(date_trunc(origination_date, month)) from {{ ref('fct_originations') }}),
            (select min(date_trunc(payment_date, month)) from {{ ref('fct_payments') }})
        ) as min_business_month
),

date_spine as (
    select distinct
        d.month_start_date as period_month,
        d.year_number,
        d.month_number,
        d.month_name
    from {{ ref('dim_date') }} d
    cross join business_range b
    where d.date <= current_date()
      and d.month_start_date >= b.min_business_month
),

-- Combinaciones dimensionales unicas para expandir el spine
dim_combos as (
    select distinct
        p.product_code,
        p.product_name,
        c.customer_segment
    from {{ ref('dim_products') }} p
    cross join (
        select distinct customer_segment 
        from {{ ref('dim_customers') }}
        where customer_segment is not null
    ) c
),

-- Spine expandido: 1 row por combinacion (mes, producto, segmento)
full_spine as (
    select
        d.period_month,
        d.year_number,
        d.month_number,
        d.month_name,
        c.product_code,
        c.product_name,
        c.customer_segment
    from date_spine d
    cross join dim_combos c
),

applications_monthly as (
    select
        date_trunc(a.application_date, month) as period_month,
        a.product_code,
        c.customer_segment,
        count(*) as applications_count,
        countif(a.is_approved) as approved_applications_count,
        countif(a.is_rejected) as rejected_applications_count,
        countif(a.was_originated) as originated_applications_count
    from {{ ref('fct_applications') }} a
    left join {{ ref('dim_customers') }} c on a.customer_id = c.customer_id
    group by 1, 2, 3
),

originations_monthly as (
    select
        date_trunc(o.origination_date, month) as period_month,
        o.product_code,
        c.customer_segment,
        count(*) as originations_count,
        sum(o.approved_amount_ars) as approved_amount_ars
    from {{ ref('fct_originations') }} o
    left join {{ ref('dim_customers') }} c on o.customer_id = c.customer_id
    group by 1, 2, 3
),

payments_monthly as (
    select
        date_trunc(p.payment_date, month) as period_month,
        o.product_code,
        c.customer_segment,
        count(*) as payments_count,
        countif(p.is_delinquent_payment) as delinquent_payments_count,
        sum(p.days_past_due) as sum_days_past_due
    from {{ ref('fct_payments') }} p
    left join {{ ref('fct_originations') }} o on p.origination_id = o.origination_id
    left join {{ ref('dim_customers') }} c on p.customer_id = c.customer_id
    group by 1, 2, 3
),

final as (
    select

        -- Grano dimensional
        s.period_month,
        s.year_number,
        s.month_number,
        s.month_name,
        s.product_code,
        s.product_name,
        s.customer_segment,

        -- Metricas base de applications
        coalesce(a.applications_count, 0) as applications_count,
        coalesce(a.approved_applications_count, 0) as approved_applications_count,
        coalesce(a.rejected_applications_count, 0) as rejected_applications_count,

        -- Metricas base de originations
        coalesce(o.originations_count, 0) as originations_count,
        coalesce(o.approved_amount_ars, 0) as approved_amount_ars,

        -- Metricas base de payments
        coalesce(p.payments_count, 0) as payments_count,
        coalesce(p.delinquent_payments_count, 0) as delinquent_payments_count,
        coalesce(p.sum_days_past_due, 0) as sum_days_past_due,

        -- Metadata de refresh
        current_timestamp() as dbt_updated_at

    from full_spine s
    left join applications_monthly a
        on s.period_month = a.period_month
        and s.product_code = a.product_code
        and s.customer_segment = a.customer_segment
    left join originations_monthly o
        on s.period_month = o.period_month
        and s.product_code = o.product_code
        and s.customer_segment = o.customer_segment
    left join payments_monthly p
        on s.period_month = p.period_month
        and s.product_code = p.product_code
        and s.customer_segment = p.customer_segment
)

select * from final