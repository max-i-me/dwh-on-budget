{{
    config(
        materialized='view'
    )
}}

-- Calculate PR cycle time metrics by repository and time period
with pr_facts as (
    select
        f.repo_key,
        r.repository_name,
        r.repository_full_name,
        d.date,
        d.year,
        d.month,
        d.week_of_year,
        f.time_to_merge_hours,
        f.is_merged
    from {{ ref('fct_pull_requests') }} f
    join {{ ref('dim_repositories') }} r on f.repo_key = r.repo_key
    join {{ ref('dim_dates') }} d on f.created_date_key = d.date_key
    where f.is_merged = true
        and f.time_to_merge_hours is not null
        and f.time_to_merge_hours >= 0
),

weekly_metrics as (
    select
        repository_name,
        repository_full_name,
        year,
        week_of_year,
        min(date) as week_start_date,
        
        count(*) as merged_pr_count,
        avg(time_to_merge_hours) as avg_hours_to_merge,
        median(time_to_merge_hours) as median_hours_to_merge,
        min(time_to_merge_hours) as min_hours_to_merge,
        max(time_to_merge_hours) as max_hours_to_merge,
        
        -- Percentiles
        approx_quantile(time_to_merge_hours, 0.25) as p25_hours_to_merge,
        approx_quantile(time_to_merge_hours, 0.75) as p75_hours_to_merge,
        approx_quantile(time_to_merge_hours, 0.90) as p90_hours_to_merge,
        
        -- Convert to days for readability
        avg(time_to_merge_hours) / 24 as avg_days_to_merge,
        median(time_to_merge_hours) / 24 as median_days_to_merge,
        approx_quantile(time_to_merge_hours, 0.90) / 24 as p90_days_to_merge
        
    from pr_facts
    group by repository_name, repository_full_name, year, week_of_year
),

monthly_metrics as (
    select
        repository_name,
        repository_full_name,
        year,
        month,
        min(date) as month_start_date,
        
        count(*) as merged_pr_count,
        avg(time_to_merge_hours) as avg_hours_to_merge,
        median(time_to_merge_hours) as median_hours_to_merge,
        min(time_to_merge_hours) as min_hours_to_merge,
        max(time_to_merge_hours) as max_hours_to_merge,
        
        -- Percentiles
        approx_quantile(time_to_merge_hours, 0.25) as p25_hours_to_merge,
        approx_quantile(time_to_merge_hours, 0.75) as p75_hours_to_merge,
        approx_quantile(time_to_merge_hours, 0.90) as p90_hours_to_merge,
        
        -- Convert to days
        avg(time_to_merge_hours) / 24 as avg_days_to_merge,
        median(time_to_merge_hours) / 24 as median_days_to_merge,
        approx_quantile(time_to_merge_hours, 0.90) / 24 as p90_days_to_merge
        
    from pr_facts
    group by repository_name, repository_full_name, year, month
)

-- Union weekly and monthly for a unified view
select
    'weekly' as period_type,
    repository_name,
    repository_full_name,
    year,
    week_of_year as period_number,
    week_start_date as period_start_date,
    merged_pr_count,
    avg_hours_to_merge,
    median_hours_to_merge,
    min_hours_to_merge,
    max_hours_to_merge,
    p25_hours_to_merge,
    p75_hours_to_merge,
    p90_hours_to_merge,
    avg_days_to_merge,
    median_days_to_merge,
    p90_days_to_merge
from weekly_metrics

union all

select
    'monthly' as period_type,
    repository_name,
    repository_full_name,
    year,
    month as period_number,
    month_start_date as period_start_date,
    merged_pr_count,
    avg_hours_to_merge,
    median_hours_to_merge,
    min_hours_to_merge,
    max_hours_to_merge,
    p25_hours_to_merge,
    p75_hours_to_merge,
    p90_hours_to_merge,
    avg_days_to_merge,
    median_days_to_merge,
    p90_days_to_merge
from monthly_metrics
