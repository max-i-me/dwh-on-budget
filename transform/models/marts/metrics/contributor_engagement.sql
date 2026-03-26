{{
    config(
        materialized='view'
    )
}}

-- Analyze contributor engagement patterns
with activity as (
    select * from {{ ref('int_contributor_activity') }}
    where is_bot = false  -- Exclude bots
),

user_first_activity as (
    select
        user_id,
        repository_full_name,
        min(activity_at) as first_activity_at
    from activity
    group by user_id, repository_full_name
),

enriched_activity as (
    select
        a.*,
        f.first_activity_at,
        case 
            when date_trunc('month', a.activity_at) = date_trunc('month', f.first_activity_at)
            then 'new'
            else 'returning'
        end as contributor_type
    from activity a
    join user_first_activity f
        on a.user_id = f.user_id
        and a.repository_full_name = f.repository_full_name
),

monthly_engagement as (
    select
        repository_full_name,
        activity_year as year,
        extract(month from activity_month) as month,
        activity_month as month_start_date,
        
        -- Overall metrics
        count(distinct user_id) as unique_contributors,
        count(*) as total_activities,
        
        -- By contributor type
        count(distinct case when contributor_type = 'new' then user_id end) as new_contributors,
        count(distinct case when contributor_type = 'returning' then user_id end) as returning_contributors,
        
        -- By activity type
        count(distinct case when activity_type = 'commit_created' then user_id end) as committers,
        count(distinct case when activity_type = 'pr_created' then user_id end) as pr_creators,
        count(distinct case when activity_type = 'issue_created' then user_id end) as issue_creators,
        count(distinct case when activity_type = 'comment_created' then user_id end) as commenters,
        
        -- Activity counts
        sum(case when activity_type = 'commit_created' then 1 else 0 end) as commit_count,
        sum(case when activity_type = 'pr_created' then 1 else 0 end) as pr_count,
        sum(case when activity_type = 'issue_created' then 1 else 0 end) as issue_count,
        sum(case when activity_type = 'comment_created' then 1 else 0 end) as comment_count,
        
        -- Engagement ratios
        count(*) * 1.0 / count(distinct user_id) as activities_per_contributor,
        count(distinct case when contributor_type = 'returning' then user_id end) * 100.0 
            / nullif(count(distinct user_id), 0) as returning_contributor_pct
        
    from enriched_activity
    group by repository_full_name, activity_year, extract(month from activity_month), activity_month
),

top_contributors as (
    select
        repository_full_name,
        activity_year as year,
        extract(month from activity_month) as month,
        user_login,
        user_id,
        count(*) as activity_count,
        count(distinct activity_type) as activity_type_count,
        row_number() over (
            partition by repository_full_name, activity_year, extract(month from activity_month)
            order by count(*) desc
        ) as contributor_rank
    from enriched_activity
    group by repository_full_name, activity_year, extract(month from activity_month), user_login, user_id
    qualify contributor_rank <= 10
)

select
    m.*,
    -- Add top contributor info as a nested structure would be ideal,
    -- but for simplicity we'll create a separate view
    current_timestamp as _calculated_at
from monthly_engagement m
