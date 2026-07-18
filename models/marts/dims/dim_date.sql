-- Dimension de fechas conformed a nivel warehouse. Sigue Kimball: 1 fila por
-- dia, con atributos temporales pre-calculados y flags de business day AR.
--
--
-- Rango: 2020-01-01 a 2030-12-31 (11 anios, ~4018 filas).
-- Feriados nacionales AR provenientes del seed holidays_ar (Ley 27.399).
--
-- Vive en schema core (analytics_core en prod, dbt_carlos_core en dev)
-- para explicitar que es una conformed dimension compartida entre dominios.
-- Es el primer paso hacia una organizacion productiva por schemas de dominio
-- (analytics_credit, analytics_risk, analytics_marketing).

{{
    config(
        materialized='table',
        schema='core',
        tags=['mart', 'dim', 'date']
    )
}}

with date_spine as (

    {{
        dbt_utils.date_spine(
            datepart="day",
            start_date="cast('2020-01-01' as date)",
            end_date="cast('2031-01-01' as date)"
        )
    }}

),

dates as (

    select
        cast(date_day as date) as date
    from date_spine

),

holidays as (

    select
        date,
        holiday_name,
        holiday_type,
        is_bank_holiday
    from {{ ref('holidays_ar') }}

),

joined as (

    select
        d.date,
        h.holiday_name,
        h.holiday_type,
        coalesce(h.is_bank_holiday, false) as is_bank_holiday
    from dates d
    left join holidays h on d.date = h.date

),

enriched as (

    select

        -- Natural key + surrogate key
        date,
        cast(format_date('%Y%m%d', date) as int64) as date_sk,

        -- Componentes del dia
        extract(dayofweek from date) as day_of_week_number,
        case extract(dayofweek from date)
            when 1 then 'Domingo'
            when 2 then 'Lunes'
            when 3 then 'Martes'
            when 4 then 'Miercoles'
            when 5 then 'Jueves'
            when 6 then 'Viernes'
            when 7 then 'Sabado'
        end as day_name,
        case extract(dayofweek from date)
            when 1 then 'Dom'
            when 2 then 'Lun'
            when 3 then 'Mar'
            when 4 then 'Mie'
            when 5 then 'Jue'
            when 6 then 'Vie'
            when 7 then 'Sab'
        end as day_name_short,
        extract(day from date) as day_of_month,
        extract(dayofyear from date) as day_of_year,

        -- Componentes de semana
        extract(week from date) as week_of_year,
        date_trunc(date, week(monday)) as week_start_date,
        date_add(date_trunc(date, week(monday)), interval 6 day) as week_end_date,

        -- Componentes de mes
        extract(month from date) as month_number,
        case extract(month from date)
            when 1 then 'Enero'
            when 2 then 'Febrero'
            when 3 then 'Marzo'
            when 4 then 'Abril'
            when 5 then 'Mayo'
            when 6 then 'Junio'
            when 7 then 'Julio'
            when 8 then 'Agosto'
            when 9 then 'Septiembre'
            when 10 then 'Octubre'
            when 11 then 'Noviembre'
            when 12 then 'Diciembre'
        end as month_name,
        format_date('%b', date) as month_short,
        date_trunc(date, month) as month_start_date,
        last_day(date, month) as month_end_date,

        -- Componentes de trimestre
        extract(quarter from date) as quarter_number,
        concat('Q', cast(extract(quarter from date) as string)) as quarter_name,
        date_trunc(date, quarter) as quarter_start_date,
        last_day(date, quarter) as quarter_end_date,

        -- Componentes de anio
        extract(year from date) as year_number,
        date_trunc(date, year) as year_start_date,
        last_day(date, year) as year_end_date,

        -- Concatenaciones para slicers en Power BI
        format_date('%Y-%m', date) as year_month,
        concat(cast(extract(year from date) as string), '-Q', cast(extract(quarter from date) as string)) as year_quarter,

        -- Flags de business day
        case
            when extract(dayofweek from date) in (1, 7) then true
            else false
        end as is_weekend,
        case
            when extract(dayofweek from date) not in (1, 7) then true
            else false
        end as is_weekday,

        -- Flags de feriado (desde el seed)
        case when holiday_name is not null then true else false end as is_holiday,
        holiday_name,
        holiday_type,
        is_bank_holiday,

        -- Business day = weekday AND NOT bank holiday
        case
            when extract(dayofweek from date) in (1, 7) then false
            when is_bank_holiday = true then false
            else true
        end as is_business_day,

        -- Flags de cierre de periodo
        case when date = last_day(date, month) then true else false end as is_month_end,
        case when date = date_trunc(date, month) then true else false end as is_month_start,
        case when date = last_day(date, quarter) then true else false end as is_quarter_end,
        case when date = last_day(date, year) then true else false end as is_year_end,

        current_timestamp() as dbt_updated_at

    from joined

)

select * from enriched