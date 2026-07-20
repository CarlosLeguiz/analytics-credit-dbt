-- rpt_executive_summary: reporting mart mensual para la pagina "Resumen" del
-- dashboard ejecutivo. Grano: 1 row por mes.
--
-- Power BI es visualizador puro. Todas las metricas base viven
-- Los ratios (approval rate, delinquency rate,
-- ticket promedio, dpd promedio) se calculan en Power BI con DIVIDE de SUMs
-- para que funcionen correctamente bajo cualquier filter context (mes, quarter,
-- year, YTD). Nunca pre-calculamos AVERAGE o ratios directos: el promedio de
-- promedios y el ratio de ratios son matematicamente incorrectos cuando cambia
-- el filtro temporal.
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

-- Spine temporal: garantiza que meses sin actividad aparezcan con 0 en vez de
-- ausentes. Sin esto, un mes sin originaciones desaparece del grafico de linea
-- temporal y Power BI muestra "huecos" visuales.
-- Rango de negocio: primer mes con actividad en cualquier fact
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

applications_monthly as (

    select
        date_trunc(application_date, month) as period_month,
        count(*) as applications_count,
        countif(is_approved) as approved_applications_count,
        countif(is_rejected) as rejected_applications_count,
        countif(was_originated) as originated_applications_count
    from {{ ref('fct_applications') }}
    group by 1

),

originations_monthly as (

    select
        date_trunc(origination_date, month) as period_month,
        count(*) as originations_count,
        sum(approved_amount_ars) as approved_amount_ars
    from {{ ref('fct_originations') }}
    group by 1

),

payments_monthly as (

    select
        date_trunc(payment_date, month) as period_month,
        count(*) as payments_count,
        countif(is_delinquent_payment) as delinquent_payments_count,
        sum(days_past_due) as sum_days_past_due
    from {{ ref('fct_payments') }}
    group by 1

),

final as (

    select

        -- Grano temporal y descriptores
        d.period_month,
        d.year_number,
        d.month_number,
        d.month_name,

        -- Metricas base de applications (bucket para approval rate)
        coalesce(a.applications_count, 0) as applications_count,
        coalesce(a.approved_applications_count, 0) as approved_applications_count,
        coalesce(a.rejected_applications_count, 0) as rejected_applications_count,

        -- Metricas base de originations (bucket para volumen y ticket)
        coalesce(o.originations_count, 0) as originations_count,
        coalesce(o.approved_amount_ars, 0) as approved_amount_ars,

        -- Metricas base de payments (bucket para delinquency y dpd)
        coalesce(p.payments_count, 0) as payments_count,
        coalesce(p.delinquent_payments_count, 0) as delinquent_payments_count,
        coalesce(p.sum_days_past_due, 0) as sum_days_past_due,

        -- Metadata de refresh
        current_timestamp() as dbt_updated_at

    from date_spine d
    left join applications_monthly a on d.period_month = a.period_month
    left join originations_monthly o on d.period_month = o.period_month
    left join payments_monthly p on d.period_month = p.period_month

)

select * from final