{{
    config(
        materialized='view'
    )
}}

-- Analyze release velocity and patterns
with releases as (
    select
        r.repository_full_name,
        r.repository_name,
        rel.tag_name,
        rel.release_name,
        rel.is_prerelease,
        rel.is_draft,
        rel.published_at,
        rel.created_at
    from {{ ref('stg_releases') }} rel
    join {{ ref('dim_repositories') }} r
        on rel.repository_full_name = r.repository_full_name
    where rel.is_draft = false  -- Exclude drafts
        and rel.published_at is not null
),

release_intervals as (
    select
        *,
        lag(published_at) over (
            partition by repository_full_name 
            order by published_at
        ) as previous_release_at,
        
        datediff('day', 
            lag(published_at) over (partition by repository_full_name order by published_at),
            published_at
        ) as days_since_last_release
        
    from releases
),

commits_per_release as (
    select
        c.repository_full_name,
        date_trunc('month', c.commit_date) as commit_month,
        count(*) as commit_count
    from {{ ref('stg_commits') }} c
    group by c.repository_full_name, date_trunc('month', c.commit_date)
),

monthly_release_metrics as (
    select
        r.repository_name,
        r.repository_full_name,
        date_trunc('month', r.published_at) as release_month,
        extract(year from r.published_at) as year,
        extract(month from r.published_at) as month,
        
        -- Release counts
        count(*) as release_count,
        count(case when r.is_prerelease = false then 1 end) as stable_release_count,
        count(case when r.is_prerelease = true then 1 end) as prerelease_count,
        
        -- Timing metrics
        avg(r.days_since_last_release) as avg_days_between_releases,
        median(r.days_since_last_release) as median_days_between_releases,
        min(r.days_since_last_release) as min_days_between_releases,
        max(r.days_since_last_release) as max_days_between_releases,
        
        -- Release cadence (releases per month)
        count(*) * 1.0 as releases_per_month
        
    from release_intervals r
    group by 
        r.repository_name,
        r.repository_full_name,
        date_trunc('month', r.published_at),
        extract(year from r.published_at),
        extract(month from r.published_at)
),

quarterly_metrics as (
    select
        r.repository_name,
        r.repository_full_name,
        extract(year from r.published_at) as year,
        extract(quarter from r.published_at) as quarter,
        
        count(*) as release_count,
        count(case when r.is_prerelease = false then 1 end) as stable_release_count,
        avg(r.days_since_last_release) as avg_days_between_releases,
        median(r.days_since_last_release) as median_days_between_releases
        
    from release_intervals r
    group by 
        r.repository_name,
        r.repository_full_name,
        extract(year from r.published_at),
        extract(quarter from r.published_at)
)

-- Return monthly metrics
select
    'monthly' as period_type,
    repository_name,
    repository_full_name,
    year,
    month as period_number,
    null as quarter,
    release_month as period_start_date,
    release_count,
    stable_release_count,
    prerelease_count,
    avg_days_between_releases,
    median_days_between_releases,
    min_days_between_releases,
    max_days_between_releases,
    releases_per_month as releases_per_period
from monthly_release_metrics

union all

select
    'quarterly' as period_type,
    repository_name,
    repository_full_name,
    year,
    null as period_number,
    quarter,
    cast(year || '-' || (quarter * 3 - 2) || '-01' as date) as period_start_date,
    release_count,
    stable_release_count,
    null as prerelease_count,
    avg_days_between_releases,
    median_days_between_releases,
    null as min_days_between_releases,
    null as max_days_between_releases,
    release_count * 1.0 / 3 as releases_per_period
from quarterly_metrics
