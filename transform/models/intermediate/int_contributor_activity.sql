{{
    config(
        materialized='view'
    )
}}

-- Union all contributor activities into a single stream
with issue_activity as (
    select
        author_id as user_id,
        author_login as user_login,
        repository_full_name,
        'issue_created' as activity_type,
        created_at as activity_at,
        issue_id::varchar as activity_id
    from {{ ref('stg_issues') }}
    where author_id is not null
),

pr_activity as (
    select
        author_id as user_id,
        author_login as user_login,
        repository_full_name,
        'pr_created' as activity_type,
        created_at as activity_at,
        pull_request_id::varchar as activity_id
    from {{ ref('stg_pull_requests') }}
    where author_id is not null
),

comment_activity as (
    select
        author_id as user_id,
        author_login as user_login,
        repository_full_name,
        'comment_created' as activity_type,
        created_at as activity_at,
        comment_id::varchar as activity_id
    from {{ ref('stg_issue_comments') }}
    where author_id is not null
),

commit_activity as (
    select
        author_id as user_id,
        author_login as user_login,
        repository_full_name,
        'commit_created' as activity_type,
        commit_date as activity_at,
        commit_sha as activity_id
    from {{ ref('stg_commits') }}
    where author_id is not null
),

all_activity as (
    select * from issue_activity
    union all
    select * from pr_activity
    union all
    select * from comment_activity
    union all
    select * from commit_activity
),

enriched as (
    select
        a.*,
        u.is_bot,
        
        -- Time dimensions
        date_trunc('day', a.activity_at) as activity_date,
        date_trunc('week', a.activity_at) as activity_week,
        date_trunc('month', a.activity_at) as activity_month,
        date_trunc('year', a.activity_at) as activity_year
        
    from all_activity a
    left join {{ ref('stg_users') }} u
        on a.user_id = u.user_id
)

select * from enriched
