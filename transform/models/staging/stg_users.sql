{{
    config(
        materialized='view'
    )
}}

-- Deduplicate users from all sources
with issue_users as (
    select distinct
        author_id as user_id,
        author_login as user_login
    from {{ ref('stg_issues') }}
    where author_id is not null
),

pr_users as (
    select distinct
        author_id as user_id,
        author_login as user_login
    from {{ ref('stg_pull_requests') }}
    where author_id is not null
),

comment_users as (
    select distinct
        author_id as user_id,
        author_login as user_login
    from {{ ref('stg_issue_comments') }}
    where author_id is not null
),

commit_users as (
    select distinct
        author_id as user_id,
        author_login as user_login
    from {{ ref('stg_commits') }}
    where author_id is not null
),

stargazer_users as (
    select distinct
        user_id,
        user_login
    from {{ ref('stg_stargazers') }}
    where user_id is not null
),

all_users as (
    select * from issue_users
    union
    select * from pr_users
    union
    select * from comment_users
    union
    select * from commit_users
    union
    select * from stargazer_users
),

deduplicated as (
    select
        user_id,
        -- Take the first login if there are multiple (shouldn't happen)
        min(user_login) as user_login
    from all_users
    group by user_id
),

final as (
    select
        user_id,
        user_login,
        
        -- Bot detection
        case
            when lower(user_login) like '%bot%' then true
            when lower(user_login) like '%[bot]%' then true
            when lower(user_login) in ('dependabot', 'github-actions', 'renovate') then true
            else false
        end as is_bot,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from deduplicated
)

select * from final
