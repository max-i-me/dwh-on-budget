{% macro generate_date_spine(start_date, end_date) %}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ start_date ~ "' as date)",
        end_date="cast('" ~ end_date ~ "' as date)"
    ) }}
),

enriched as (
    select
        date_day as date,
        
        -- Date key (YYYYMMDD format)
        cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
        
        -- Date parts
        extract(year from date_day) as year,
        extract(quarter from date_day) as quarter,
        extract(month from date_day) as month,
        extract(week from date_day) as week_of_year,
        extract(dayofweek from date_day) as day_of_week,
        extract(dayofyear from date_day) as day_of_year,
        
        -- Date names
        strftime(date_day, '%B') as month_name,
        strftime(date_day, '%A') as day_name,
        
        -- Flags
        case when extract(dayofweek from date_day) in (0, 6) then true else false end as is_weekend,
        case when extract(month from date_day) in (12, 1, 2) then true else false end as is_winter,
        case when extract(month from date_day) in (3, 4, 5) then true else false end as is_spring,
        case when extract(month from date_day) in (6, 7, 8) then true else false end as is_summer,
        case when extract(month from date_day) in (9, 10, 11) then true else false end as is_fall
        
    from date_spine
)

select * from enriched

{% endmacro %}
