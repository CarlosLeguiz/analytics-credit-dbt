-- rpt_portfolio_delinquency: reporting mart mensual de distribucion de cartera
-- por bucket de mora. Grano: (period_month, bucket_code, product_name).
--
-- Responde: como se distribuye mi cartera por bucket de mora a lo largo del
-- tiempo, y como varia por producto?
--
-- Filosofia Sr: Power BI hace SUM/COUNT/DIVIDE, no calcula filter context.
-- Ratios (% mora por bucket, DPD promedio) se calculan en Power BI con
-- DIVIDE de SUMs para preservar correctness bajo cualquier filter.

{{
    config(
        materialized='table',
        tags=['mart', 'rpt', 'reporting', 'portfolio']
    )
}}

with

business_range as (
    select min(date_trunc(payment_date, month)) as min_business_month
    from {{ ref('fct_payments') }}
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

dim_combos as (
    select distinct
        bucket_code,
        bucket_name,
        severity_order,
        product_name,
        product_code
    from (
        select 
            p.bucket_code,
            p.bucket_name,
            p.severity_order,
            pr.product_name,
            pr.product_code
        from {{ ref('fct_payments') }} p
        left join {{ ref('fct_originations') }} o on p.origination_id = o.origination_id
        left join {{ ref('dim_products') }} pr on o.product_code = pr.product_code
    )
),

full_spine as (
    select
        d.period_month,
        d.year_number,
        d.month_number,
        d.month_name,
        c.bucket_code,
        c.bucket_name,
        c.severity_order,
        c.product_code,
        c.product_name
    from date_spine d
    cross join dim_combos c
),

payments_monthly as (
    select
        date_trunc(p.payment_date, month) as period_month,
        p.bucket_code,
        pr.product_code,
        count(*) as payments_count,
        count(distinct p.customer_id) as customers_in_bucket_count,
        countif(p.is_delinquent_payment) as delinquent_payments_count,
        sum(p.due_amount_ars) as total_due_amount_ars,
        sum(p.paid_amount_ars) as total_paid_amount_ars,
        sum(p.days_past_due) as sum_days_past_due
    from {{ ref('fct_payments') }} p
    left join {{ ref('fct_originations') }} o on p.origination_id = o.origination_id
    left join {{ ref('dim_products') }} pr on o.product_code = pr.product_code
    group by 1, 2, 3
),

final as (
    select
        s.period_month,
        s.year_number,
        s.month_number,
        s.month_name,
        s.bucket_code,
        s.bucket_name,
        s.severity_order,
        s.product_code,
        s.product_name,
        coalesce(p.payments_count, 0) as payments_count,
        coalesce(p.customers_in_bucket_count, 0) as customers_in_bucket_count,
        coalesce(p.delinquent_payments_count, 0) as delinquent_payments_count,
        coalesce(p.total_due_amount_ars, 0) as total_due_amount_ars,
        coalesce(p.total_paid_amount_ars, 0) as total_paid_amount_ars,
        coalesce(p.sum_days_past_due, 0) as sum_days_past_due,
        current_timestamp() as dbt_updated_at
    from full_spine s
    left join payments_monthly p
        on s.period_month = p.period_month
        and s.bucket_code = p.bucket_code
        and s.product_code = p.product_code
)

select * from final